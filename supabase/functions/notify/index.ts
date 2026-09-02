// Edge Function „notify": Push für eine Zeile aus `notifications`.
//
// Aufgerufen vom Datenbank-Trigger `notifications_push` (Migration 0033)
// über pg_net, mit `{ "id": "<notification-id>" }` und dem gemeinsamen
// Geheimnis im Kopf `x-notify-secret`. Die Function lädt die Zeile selbst
// nach — sie vertraut dem Aufrufer nichts außer der ID.
//
// Was hier rausgeht, ist inhaltsleer: Der Push sagt „Du hast eine neue
// Freundschaftsanfrage" und nennt weder Namen noch Absender. Google
// erfährt, *dass* ein Gerät geweckt wird, nicht *warum*. Den Inhalt holt
// sich die App danach von Supabase, unter RLS.
//
// Fehlt die FCM-Konfiguration, antwortet die Function mit 503 und einem
// klaren Satz — nicht mit 200 und nichts. Ein Push-System, das „ok" sagt
// und nicht sendet, wäre der Fehler, den dieses Projekt schon dreimal hatte.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const TEXTE: Record<string, { title: string; body: string }> = {
  friend_request: {
    title: "BrewMates",
    body: "Du hast eine neue Freundschaftsanfrage 🍻",
  },
  friend_accepted: {
    title: "BrewMates",
    body: "Deine Freundschaftsanfrage wurde angenommen 🍻",
  },
  beacon: {
    title: "BrewMates",
    body: "Ein BrewMate ist auf ein Bier unterwegs",
  },
  session_toast: {
    title: "BrewMates",
    body: "Jemand hat dir zugeprostet 🍻",
  },
  session_joined: {
    title: "BrewMates",
    body: "Jemand ist bei deinem Beacon dabei 🍻",
  },
};

// --- Google OAuth2 mit Dienstkonto (RS256-JWT, WebCrypto) -----------------

function b64url(input: Uint8Array | string): string {
  const s = typeof input === "string"
    ? btoa(unescape(encodeURIComponent(input)))
    : btoa(String.fromCharCode(...input));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

let tokenCache: { value: string; exp: number } | null = null;

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (tokenCache && tokenCache.exp - 60 > now) return tokenCache.value;

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`OAuth fehlgeschlagen: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  tokenCache = {
    value: json.access_token,
    exp: now + (json.expires_in ?? 3600),
  };
  return tokenCache.value;
}

// --- FCM HTTP v1 ------------------------------------------------------------

// Sendet an ein Token. "unregistered" heißt: FCM kennt das Token endgültig
// nicht mehr — dann fliegt die Zeile aus `devices`.
async function sendeAn(
  sa: ServiceAccount,
  token: string,
  text: { title: string; body: string },
  data: Record<string, string>,
): Promise<"ok" | "unregistered" | "fehler"> {
  const bearer = await accessToken(sa);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: text,
          data,
          android: {
            priority: "high",
            notification: { channel_id: "brewmates", sound: "default" },
          },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  const body = await res.text();
  if (res.status === 404 || body.includes("UNREGISTERED")) {
    return "unregistered";
  }
  console.error(`FCM ${res.status}: ${body}`);
  return "fehler";
}

// --- Einstieg ---------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  // Gemeinsames Geheimnis aus dem Vault — derselbe Wert, den der Trigger
  // mitschickt. Kein Geheimnis, kein Versand.
  // Ueber die RPC aus 0034: Das Schema `vault` ist ueber PostgREST nicht
  // erreichbar, die Funktion darf nur die Service-Rolle aufrufen.
  const { data: erwartet } = await supabase.rpc("notify_webhook_secret");
  if (!erwartet) {
    return new Response("notify_webhook_secret fehlt im Vault", {
      status: 503,
    });
  }
  if (req.headers.get("x-notify-secret") !== erwartet) {
    return new Response("forbidden", { status: 403 });
  }

  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!saRaw) {
    return new Response(
      "FCM_SERVICE_ACCOUNT ist nicht gesetzt – kein Push möglich",
      { status: 503 },
    );
  }
  const sa = JSON.parse(saRaw) as ServiceAccount;

  const { id } = await req.json().catch(() => ({}));
  if (typeof id !== "string") {
    return new Response("id fehlt", { status: 400 });
  }

  const { data: n } = await supabase
    .from("notifications")
    .select("id, recipient_id, type")
    .eq("id", id)
    .maybeSingle();
  if (!n) return new Response("unbekannte notification", { status: 404 });

  const { data: devices } = await supabase
    .from("devices")
    .select("id, push_token")
    .eq("profile_id", n.recipient_id)
    .eq("platform", "android");
  if (!devices || devices.length === 0) {
    return new Response(
      JSON.stringify({ sent: 0, reason: "keine Geräte" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const text = TEXTE[n.type] ??
    { title: "BrewMates", body: "Neue Benachrichtigung" };
  let sent = 0;
  const tot: string[] = [];
  for (const d of devices) {
    const r = await sendeAn(sa, d.push_token, text, {
      type: n.type,
      id: n.id,
    });
    if (r === "ok") sent++;
    if (r === "unregistered") tot.push(d.id);
  }
  if (tot.length > 0) {
    await supabase.from("devices").delete().in("id", tot);
  }

  return new Response(JSON.stringify({ sent, pruned: tot.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
