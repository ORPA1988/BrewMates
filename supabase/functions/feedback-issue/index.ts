// Edge Function „feedback-issue": Aus einer Meldung wird ein GitHub-Issue.
//
// Aufgerufen vom Trigger `feedback_issue` (Migration 0038) über pg_net:
//   { "id": "<feedback-id>" }                         → Issue anlegen
//   { "id": "…", "deleted": true, "github_issue": 12 } → Issue schließen
// Erkennungszeichen ist das gemeinsame Geheimnis im Kopf `x-notify-secret`
// (dasselbe wie beim Push). Die Function lädt die Zeile selbst nach.
//
// Das Issue ist **anonym**: Art, Version, Plattform, Datum, Text. Kein
// Name, keine E-Mail, keine Profil-ID. Das Repo ist öffentlich — die App
// sagt das dem Tester, bevor er tippt.
//
// Fehlt `GITHUB_TOKEN`, antwortet die Function mit 503 und einem klaren
// Satz. Die Meldung ist dann trotzdem in Supabase; ein späterer Aufruf mit
// { "backfill": true } holt die Issues nach.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OWNER = "ORPA1988";
const REPO = "BrewMates";

type Meldung = {
  id: string;
  kind: "bug" | "wish" | "data";
  body: string;
  app_version: string | null;
  platform: string | null;
  created_at: string;
  github_issue: number | null;
};

function ghHeaders(token: string): HeadersInit {
  return {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "brewmates-feedback",
    "Content-Type": "application/json",
  };
}

/// Wie die drei Arten heissen — an einer Stelle, damit Titel, Text und
/// Label nicht auseinanderlaufen.
///
/// `data` kam mit 0.10.18 dazu: eine gemeldete Datenluecke (heute die
/// Gebindegroesse zu einer EAN). Sie wirkt sofort in der Datenbank; das
/// Issue ist die Nachpruefung, nicht die Freigabe — siehe
/// docs/features/43.
const ARTEN = {
  bug: { titel: "[Fehler]", wort: "Fehler", label: "bug" },
  wish: { titel: "[Wunsch]", wort: "Wunsch", label: "wunsch" },
  data: { titel: "[Daten]", wort: "Datenpflege", label: "datenpflege" },
} as const;

function art(m: Meldung) {
  return ARTEN[m.kind] ?? ARTEN.wish;
}

function titel(m: Meldung): string {
  const erste = m.body.split("\n").map((z) => z.trim()).find((z) => z) ??
    "";
  const kurz = erste.replace(/\s+/g, " ").slice(0, 70);
  const rest = erste.length > 70 ? "…" : "";
  return `${art(m).titel} ${kurz}${rest}`;
}

function issueBody(m: Meldung): string {
  const wort = art(m).wort;
  const datum = m.created_at.slice(0, 10);
  const zitat = m.body.trim().split("\n").map((z) => `> ${z}`).join("\n");
  return [
    `**Art:** ${wort} · **Version:** ${m.app_version ?? "?"} · ` +
    `**Plattform:** ${m.platform ?? "?"} · **Gemeldet:** ${datum}`,
    "",
    zitat,
    "",
    "---",
    `Aus der App gemeldet, anonym (Meldung \`${m.id}\`).`,
    "Verwaltung: Status per Label `status:geplant` / `status:in-arbeit` / " +
    "`status:erledigt` / `status:nicht-geplant` oder Issue schließen. " +
    "Eine Antwort für den Tester ist ein Kommentar, der mit **„Antwort:“** " +
    "beginnt. Label `roadmap` nimmt den Punkt in die App-Roadmap auf " +
    "(Titel und erster Absatz erscheinen dort). " +
    "Ein Kommentar **„Roadmap: #123“** verknüpft die Meldung mit einem " +
    "anderen Roadmap-Issue.",
  ].join("\n");
}

async function issueAnlegen(token: string, m: Meldung): Promise<number> {
  const res = await fetch(
    `https://api.github.com/repos/${OWNER}/${REPO}/issues`,
    {
      method: "POST",
      headers: ghHeaders(token),
      body: JSON.stringify({
        title: titel(m),
        body: issueBody(m),
        labels: ["feedback", art(m).label],
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`GitHub ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return json.number as number;
}

async function issueSchliessen(token: string, nummer: number): Promise<void> {
  const base = `https://api.github.com/repos/${OWNER}/${REPO}/issues/${nummer}`;
  await fetch(`${base}/comments`, {
    method: "POST",
    headers: ghHeaders(token),
    body: JSON.stringify({ body: "Vom Absender in der App zurückgezogen." }),
  });
  const res = await fetch(base, {
    method: "PATCH",
    headers: ghHeaders(token),
    body: JSON.stringify({ state: "closed", state_reason: "not_planned" }),
  });
  if (!res.ok) {
    throw new Error(`GitHub ${res.status}: ${await res.text()}`);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: erwartet } = await supabase.rpc("notify_webhook_secret");
  if (!erwartet) {
    return new Response("notify_webhook_secret fehlt im Vault", {
      status: 503,
    });
  }
  if (req.headers.get("x-notify-secret") !== erwartet) {
    return new Response("forbidden", { status: 403 });
  }

  // Beide Namen gelten — je nachdem, unter welchem der Schlüssel eingetragen
  // wurde (ein paralleler Versuch nannte ihn GITHUB_FEEDBACK_TOKEN).
  const token = Deno.env.get("GITHUB_TOKEN") ??
    Deno.env.get("GITHUB_FEEDBACK_TOKEN");
  if (!token) {
    return new Response(
      "GITHUB_TOKEN ist nicht gesetzt – kein GitHub-Issue möglich. " +
        "Die Meldung liegt in Supabase; { backfill: true } holt sie nach.",
      { status: 503 },
    );
  }

  const body = await req.json().catch(() => ({}));

  // Rückzug: Issue schließen, mehr gibt es nicht zu tun.
  if (body.deleted === true && typeof body.github_issue === "number") {
    await issueSchliessen(token, body.github_issue);
    return Response.json({ closed: body.github_issue });
  }

  // Nachholen: alle Meldungen ohne Issue.
  let zeilen: Meldung[] = [];
  if (body.backfill === true) {
    const { data } = await supabase
      .from("feedback")
      .select("id, kind, body, app_version, platform, created_at, github_issue")
      .is("github_issue", null)
      .order("created_at");
    zeilen = (data ?? []) as Meldung[];
  } else {
    if (typeof body.id !== "string") {
      return new Response("id fehlt", { status: 400 });
    }
    const { data } = await supabase
      .from("feedback")
      .select("id, kind, body, app_version, platform, created_at, github_issue")
      .eq("id", body.id)
      .maybeSingle();
    if (!data) return new Response("unbekannte Meldung", { status: 404 });
    zeilen = [data as Meldung];
  }

  const ergebnis: { id: string; issue: number; existing?: boolean }[] = [];
  for (const m of zeilen) {
    if (m.github_issue != null) {
      ergebnis.push({ id: m.id, issue: m.github_issue, existing: true });
      continue;
    }
    const nummer = await issueAnlegen(token, m);
    const { error } = await supabase
      .from("feedback")
      .update({ github_issue: nummer })
      .eq("id", m.id);
    if (error) {
      // Das Issue existiert jetzt, die Nummer nicht in der Zeile — laut
      // sagen, damit niemand nachher ein zweites anlegt.
      console.error(`feedback ${m.id}: Issue #${nummer} angelegt, ` +
        `Nummer nicht gespeichert: ${error.message}`);
      return new Response(`Issue #${nummer} angelegt, Speichern scheiterte`, {
        status: 500,
      });
    }
    ergebnis.push({ id: m.id, issue: nummer });
  }
  return Response.json({ created: ergebnis });
});
