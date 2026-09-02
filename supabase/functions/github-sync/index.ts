// Edge Function „github-sync": Der Stand aus GitHub wird nach Supabase
// gespiegelt — für die App, die Status, Antwort und Roadmap von dort liest.
//
// Aufrufer: der Actions-Workflow `feedback-sync.yml` bei jeder Änderung an
// einem Issue mit Label `feedback` oder `roadmap`, mit { "number": 12 }.
// { "all": true } synchronisiert alle solchen Issues (Erstbefüllung,
// Reparatur).
//
// Die Function **vertraut dem Aufrufer nichts**: Sie liest das Issue selbst
// bei GitHub nach und leitet alles daraus ab. Deshalb braucht sie kein
// Geheimnis — wer sie aufruft, kann höchstens erreichen, dass der wahre
// Stand eingetragen wird. Ein Token (`GITHUB_TOKEN`) hebt nur das
// Abruflimit; das Repo ist öffentlich.
//
// Abbildung:
//   Feedback-Issue  → feedback.status
//     geschlossen „not_planned"           → declined
//     geschlossen sonst / status:erledigt → done
//     status:geplant / status:in-arbeit   → planned
//     sonst                               → open
//   Kommentar „Antwort: …" (Owner/Collaborator) → feedback.reply
//   Kommentar „Roadmap: #N"                     → feedback.roadmap_id
//   Label roadmap → roadmap_items (Titel, erster Absatz, Status);
//     Label weg   → Punkt verschwindet aus der Roadmap.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OWNER = "ORPA1988";
const REPO = "BrewMates";
const API = `https://api.github.com/repos/${OWNER}/${REPO}`;

// Service-Rolle: schreibt an RLS vorbei — deshalb kommt jeder Wert hier aus
// GitHub, nie aus dem Request.
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

type Issue = {
  number: number;
  title: string;
  body: string | null;
  state: "open" | "closed";
  state_reason: string | null;
  labels: { name: string }[];
  pull_request?: unknown;
};

type Kommentar = { body: string; author_association: string };

function ghHeaders(): HeadersInit {
  const h: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "brewmates-sync",
  };
  const token = Deno.env.get("GITHUB_TOKEN");
  if (token) h.Authorization = `Bearer ${token}`;
  return h;
}

async function gh(path: string): Promise<Response> {
  return await fetch(`${API}${path}`, { headers: ghHeaders() });
}

const hatLabel = (i: Issue, name: string) =>
  i.labels.some((l) => l.name === name);

const normTitel = (t: string) =>
  t.toLowerCase().replace(/[„“”"'‚‘’]/g, "").replace(/\s+/g, " ").trim();

// Ohne Geheimnis braucht es eine Bremse: Ein Vollabgleich höchstens alle
// 60 s, Einzelabgleiche höchstens 60 pro Minute je Instanz. Mehr kann ein
// Fremder hier nicht auslösen als „wahren Stand eintragen" — aber er soll
// damit nicht das GitHub-Kontingent des Tokens leeren.
let letzterVollabgleich = 0;
const einzel: number[] = [];
function gebremst(all: boolean): boolean {
  const jetzt = Date.now();
  if (all) {
    if (jetzt - letzterVollabgleich < 60_000) return true;
    letzterVollabgleich = jetzt;
    return false;
  }
  while (einzel.length && jetzt - einzel[0] > 60_000) einzel.shift();
  if (einzel.length >= 60) return true;
  einzel.push(jetzt);
  return false;
}

function feedbackStatus(i: Issue): "open" | "planned" | "done" | "declined" {
  if (i.state === "closed") {
    return i.state_reason === "not_planned" ? "declined" : "done";
  }
  if (hatLabel(i, "status:erledigt")) return "done";
  if (hatLabel(i, "status:nicht-geplant")) return "declined";
  if (hatLabel(i, "status:geplant") || hatLabel(i, "status:in-arbeit")) {
    return "planned";
  }
  return "open";
}

function roadmapStatus(i: Issue): "planned" | "in_progress" | "done" {
  if (i.state === "closed" || hatLabel(i, "status:erledigt")) return "done";
  if (hatLabel(i, "status:in-arbeit")) return "in_progress";
  return "planned";
}

// Erster Absatz des Issue-Texts, ohne Markdown, höchstens 280 Zeichen.
// Bei automatisch angelegten Feedback-Issues ist das die Kopfzeile mit Art
// und Version — deshalb wird die übersprungen und das Zitat genommen.
function zusammenfassung(body: string | null, title: string): string {
  const absaetze = (body ?? "")
    .split(/\n\s*\n/)
    .map((a) => a.trim())
    .filter((a) => a && !a.startsWith("<!--") && !a.startsWith("---") &&
      !a.startsWith("**Art:**"));
  const roh = absaetze[0] ?? "";
  const text = roh
    .replace(/^>\s?/gm, "")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/[*_`#]+/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return title;
  return text.length > 280 ? text.slice(0, 279) + "…" : text;
}

// Kommentare des Teams: Antwort für den Tester und Roadmap-Verweis.
async function teamKommentare(
  nummer: number,
): Promise<{ antwort: string | null; roadmapRef: number | null }> {
  const res = await gh(`/issues/${nummer}/comments?per_page=100`);
  if (!res.ok) return { antwort: null, roadmapRef: null };
  const alle = (await res.json()) as Kommentar[];
  const team = alle.filter((k) =>
    ["OWNER", "MEMBER", "COLLABORATOR"].includes(k.author_association)
  );
  let antwort: string | null = null;
  let roadmapRef: number | null = null;
  for (const k of team) {
    const t = k.body.trim();
    const a = t.match(/^antwort:\s*([\s\S]+)$/i);
    if (a) antwort = a[1].trim().slice(0, 500);
    const r = t.match(/^roadmap:\s*#?(\d+)/i);
    if (r) roadmapRef = Number(r[1]);
  }
  return { antwort, roadmapRef };
}

async function syncIssue(nummer: number): Promise<Record<string, unknown>> {
  const res = await gh(`/issues/${nummer}`);
  if (res.status === 404 || res.status === 410) {
    // Issue gelöscht: Roadmap-Punkt weg, Meldung bleibt (ohne Verweis).
    await supabase.from("roadmap_items").delete().eq("github_issue", nummer);
    await supabase.from("feedback").update({ github_issue: null })
      .eq("github_issue", nummer);
    return { number: nummer, deleted: true };
  }
  if (!res.ok) {
    throw new Error(`GitHub ${res.status}: ${await res.text()}`);
  }
  const issue = (await res.json()) as Issue;
  if (issue.pull_request) return { number: nummer, skipped: "pull request" };

  const ergebnis: Record<string, unknown> = { number: nummer };

  // --- Roadmap ------------------------------------------------------------
  let roadmapId: string | null = null;
  if (hatLabel(issue, "roadmap")) {
    const felder = {
      title: issue.title,
      summary: zusammenfassung(issue.body, issue.title),
      status: roadmapStatus(issue),
      github_issue: nummer,
    };
    let { data: row } = await supabase.from("roadmap_items").select("id")
      .eq("github_issue", nummer).maybeSingle();
    if (!row) {
      // Vorbefüllte Punkte (0037) ohne Issue werden über den Titel adoptiert
      // — verglichen nach Normalisierung (Anführungszeichen, Leerraum,
      // Groß/klein), damit ein „ statt " keine zweite Zeile erzeugt.
      const { data: frei } = await supabase.from("roadmap_items")
        .select("id, title").is("github_issue", null);
      const ziel = normTitel(issue.title);
      row = (frei ?? []).find((r) => normTitel(r.title as string) === ziel) ??
        null;
    }
    if (row) {
      const { error } = await supabase.from("roadmap_items").update(felder)
        .eq("id", row.id);
      if (error) throw new Error(`roadmap update: ${error.message}`);
      roadmapId = row.id as string;
      ergebnis.roadmap = "updated";
    } else {
      const { data, error } = await supabase.from("roadmap_items")
        .insert({ ...felder, sort_order: 1000 + nummer }).select("id")
        .single();
      if (error) throw new Error(`roadmap insert: ${error.message}`);
      roadmapId = data.id as string;
      ergebnis.roadmap = "inserted";
    }
  } else {
    const { count } = await supabase.from("roadmap_items")
      .delete({ count: "exact" }).eq("github_issue", nummer);
    if (count) ergebnis.roadmap = "removed";
  }

  // --- Feedback -----------------------------------------------------------
  const { data: fb } = await supabase.from("feedback").select("id")
    .eq("github_issue", nummer).maybeSingle();
  if (fb) {
    const { antwort, roadmapRef } = await teamKommentare(nummer);
    const patch: Record<string, unknown> = { status: feedbackStatus(issue) };
    if (antwort !== null) patch.reply = antwort;
    if (roadmapId) {
      patch.roadmap_id = roadmapId;
    } else if (roadmapRef) {
      const { data: ziel } = await supabase.from("roadmap_items").select("id")
        .eq("github_issue", roadmapRef).maybeSingle();
      if (ziel) patch.roadmap_id = ziel.id;
    }
    const { error } = await supabase.from("feedback").update(patch)
      .eq("id", fb.id);
    if (error) throw new Error(`feedback update: ${error.message}`);
    ergebnis.feedback = patch;
  }
  return ergebnis;
}

async function alleNummern(): Promise<number[]> {
  const nummern = new Set<number>();
  for (const label of ["feedback", "roadmap"]) {
    for (let page = 1; page <= 5; page++) {
      const res = await gh(
        `/issues?state=all&labels=${label}&per_page=100&page=${page}`,
      );
      if (!res.ok) break;
      const liste = (await res.json()) as Issue[];
      for (const i of liste) if (!i.pull_request) nummern.add(i.number);
      if (liste.length < 100) break;
    }
  }
  return [...nummern].sort((a, b) => a - b);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const body = await req.json().catch(() => ({}));

  if (gebremst(body.all === true)) {
    return new Response("zu viele Abgleiche – gleich noch einmal", {
      status: 429,
      headers: { "Retry-After": "60" },
    });
  }

  try {
    if (body.all === true) {
      const nummern = await alleNummern();
      const ergebnisse = [];
      for (const n of nummern) ergebnisse.push(await syncIssue(n));
      return Response.json({ synced: ergebnisse.length, ergebnisse });
    }
    const nummer = Number(body.number);
    if (!Number.isInteger(nummer) || nummer <= 0) {
      return new Response("number fehlt", { status: 400 });
    }
    return Response.json(await syncIssue(nummer));
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 502 });
  }
});
