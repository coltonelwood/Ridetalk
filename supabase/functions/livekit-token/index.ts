// RideTalk — LiveKit token minting edge function
//
// The LiveKit API secret NEVER reaches the client. This function:
//   1. Verifies the caller's Supabase JWT (the user is signed in).
//   2. Confirms the user is a member of the requested room.
//   3. Mints a short-lived LiveKit access token scoped to that room + identity.
//
// Deploy:
//   supabase secrets set LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_URL=wss://...
//   supabase functions deploy livekit-token
//
// Call from the app (authenticated):
//   POST /functions/v1/livekit-token   { "roomId": "<uuid>" }
//   -> { "token": "<jwt>", "url": "wss://...", "identity": "<uuid>" }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2.7.2";

const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")!;
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")!;
const LIVEKIT_URL = Deno.env.get("LIVEKIT_URL")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "missing bearer token" }, 401);
    }

    // Supabase client scoped to the caller's JWT so RLS applies.
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "invalid session" }, 401);
    }
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const roomId: string | undefined = body.roomId;
    if (!roomId) {
      return json({ error: "roomId is required" }, 400);
    }

    // Verify membership (RLS-backed: this select only returns rows the user can see).
    const { data: membership, error: memErr } = await supabase
      .from("room_members")
      .select("room_id, role, user_id, left_at")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .is("left_at", null)
      .maybeSingle();

    if (memErr) return json({ error: memErr.message }, 500);
    if (!membership) {
      return json({ error: "not a member of this room" }, 403);
    }

    // Mint a LiveKit token. Room name == roomId (stable, unique).
    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity: userId,
      ttl: 60 * 60, // 1 hour; client refreshes as needed
      metadata: JSON.stringify({ role: membership.role }),
    });

    at.addGrant({
      room: roomId,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();

    return json({ token, url: LIVEKIT_URL, identity: userId }, 200);
  } catch (e) {
    console.error("livekit-token error", e);
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
