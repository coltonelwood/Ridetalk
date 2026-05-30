# RideTalk — Supabase backend

This directory holds the database schema (migrations), RLS policies, and the edge
function that mints LiveKit voice tokens.

## 1. Create a project
Create a free project at https://supabase.com. Note your:
- **Project URL** → `SUPABASE_URL`
- **anon public key** → `SUPABASE_ANON_KEY`
- **service_role key** (server-side only, never ship to the app)

## 2. Apply the schema
Run the migrations **in order**. Either paste them into the SQL editor, or use the CLI:

```bash
# with the Supabase CLI linked to your project:
supabase link --project-ref <your-ref>
supabase db push           # applies migrations/*.sql in order
```

Files:
1. `migrations/0001_init.sql` — tables, enums, triggers, realtime publication.
2. `migrations/0002_rls.sql` — Row Level Security policies.
3. `migrations/0003_functions.sql` — `create_room` / `join_room` / `leave_room` / `end_room` RPCs.

## 3. Configure Sign in with Apple
In **Authentication → Providers → Apple**:
- Enable Apple.
- Add your **Services ID**, **Team ID**, **Key ID**, and the **.p8 key**
  (from the Apple Developer portal).
- Add the redirect/callback as documented by Supabase.
- For native iOS Sign in with Apple, the app sends the Apple **identity token** to
  `supabase.auth.signInWithIdToken({ provider: 'apple', token })` — make sure the app's
  bundle ID is registered with Apple and the Services ID is configured.

## 4. Deploy the LiveKit token function
Get a LiveKit project (https://livekit.io) → **API Key**, **API Secret**, **WS URL**.

```bash
supabase secrets set \
  LIVEKIT_API_KEY=APIxxxxx \
  LIVEKIT_API_SECRET=secretxxxxx \
  LIVEKIT_URL=wss://your-project.livekit.cloud

supabase functions deploy livekit-token
```

The app calls `POST /functions/v1/livekit-token` with `{ "roomId": "<uuid>" }` and its
Supabase session token; the function returns `{ token, url, identity }` for the LiveKit
SDK to connect.

## 5. (Optional) Storage for avatars
Create a public bucket `avatars` if you want profile photos (Phase 1 feature). RLS on the
bucket should restrict writes to the owning user.

## Schema overview

| Table | Purpose |
|---|---|
| `users` | Mirror of `auth.users` so app tables can FK a public table (auto-created on signup). |
| `rider_profiles` | Rider profile, 1:1 with `users`: name, photo, vehicle type/model, emergency contact. |
| `ride_rooms` | Ride rooms: `code`, `host_id`, `lead_rider_id`, `status`, `separation_threshold_miles`. |
| `room_members` | Room ↔ rider: `role` (host/rider), `is_muted`, `subgroup`. |
| `live_locations` | Latest location per rider (upserted): lat/lng, speed, heading, battery, signal, connected. |
| `sos_alerts` | Emergency alerts: location, status (active/resolved). |
| `ride_recordings` | Recorded routes (jsonb point array) per rider. |
| `ride_stats` | 1:1 summary: distance, duration, avg/max speed. |
| `shared_music_links` | Compliant link sharing (+ placeholder sync fields). |
| `quick_messages` | Canned text alerts ("Stopping", "Slow down", …). |

Realtime is enabled on `room_members`, `live_locations`, `shared_music_links`,
`sos_alerts`, `quick_messages`, and `ride_rooms`. High-frequency location also uses Realtime
**broadcast** on channel `room:<roomId>` for instant map updates, while being upserted to
`live_locations` for "last known".

## Security notes
- Every table has RLS; riders only see rooms they belong to.
- Host-only mutations (mute/remove/end) are enforced by `is_room_host()`.
- The LiveKit **secret never leaves the server** — only the edge function holds it.
