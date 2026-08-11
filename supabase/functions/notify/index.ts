// Edge Function „notify": Beacon-Fan-out beim Session-Start.
// Aufgerufen per Database-Webhook auf INSERT in `sessions`.
// Ablauf (docs/03-architektur.md): Zielgruppe ermitteln → notifications
// schreiben → Push via FCM/APNs/WNS (Phase 1: FCM/APNs, WNS folgt).

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const payload = await req.json();
  const session = payload.record;
  if (!session || payload.type !== "INSERT") {
    return new Response("ignored", { status: 200 });
  }

  // Stealth-Sessions lösen keinerlei Benachrichtigung aus.
  if (session.visibility === "private") {
    return new Response("stealth", { status: 200 });
  }

  // Service-Role: umgeht RLS bewusst – dieser Code ist die Vertrauensgrenze.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Zielgruppe: alle Freunde bzw. Crew-Mitglieder (ohne den Host selbst).
  let recipientIds: string[] = [];
  if (session.visibility === "crew" && session.crew_id) {
    const { data } = await supabase
      .from("crew_members")
      .select("profile_id")
      .eq("crew_id", session.crew_id)
      .neq("profile_id", session.host_id);
    recipientIds = (data ?? []).map((r) => r.profile_id);
  } else {
    const { data } = await supabase
      .from("friendships")
      .select("requester_id, addressee_id")
      .eq("status", "accepted")
      .or(`requester_id.eq.${session.host_id},addressee_id.eq.${session.host_id}`);
    recipientIds = (data ?? []).map((r) =>
      r.requester_id === session.host_id ? r.addressee_id : r.requester_id
    );
  }

  if (recipientIds.length === 0) {
    return new Response("no recipients", { status: 200 });
  }

  // Quelle der Wahrheit für die In-App-Glocke.
  await supabase.from("notifications").insert(
    recipientIds.map((recipient_id) => ({
      recipient_id,
      type: "beacon",
      actor_id: session.host_id,
      subject_type: "session",
      subject_id: session.id,
    })),
  );

  // TODO Phase 1: Geräte-Tokens aus `devices` laden und via FCM (Android),
  // APNs (iOS) und WNS (Windows) pushen. Bis dahin liefert Supabase Realtime
  // die In-App-Benachrichtigung.

  return new Response(JSON.stringify({ notified: recipientIds.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
