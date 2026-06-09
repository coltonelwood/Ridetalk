# RideTalk — Quick Setup (~40 min)

The fastest path from clone → two iPhones talking. Detailed docs: `supabase/README.md`,
`docs/LIVEKIT_SETUP.md`, `ios/README.md`.

> 🧪 **No backend yet?** You can skip ALL of this and explore every screen right now:
> build the app (step 6–7 with the placeholder secrets file) and tap **"Explore in Demo
> Mode"** on the sign-in screen.

---

## 🔑 Key safety — read this first

| Key | Where it goes | Notes |
|---|---|---|
| `anon` **public** key | the iOS app (`Secrets.xcconfig`) | Safe to ship — RLS protects data |
| `sb_secret_…` / `service_role` | **NOWHERE in this project** | Bypasses RLS. Never put it in the app, a chat, or git. If it ever leaks, **rotate it immediately** (Dashboard → Settings → API) |

The LiveKit edge function only needs the LiveKit key/secret — not the Supabase secret.

---

## 1. Database (5 min)
Supabase **SQL Editor** → paste & **Run** each file **in order**:
```
supabase/migrations/0001_init.sql
supabase/migrations/0002_rls.sql
supabase/migrations/0003_functions.sql
supabase/migrations/0004_crash_detection.sql
supabase/migrations/0005_music_sync.sql
```
Realtime is enabled by `0001` (`alter publication supabase_realtime …`) — no manual
Replication toggles needed.

## 2. Sign in with Apple (10 min) — requires paid Apple Developer account
Apple Developer Portal: create a **Services ID**, note your **Team ID**, create a **Key**
(Sign in with Apple) → download the **.p8** + note the **Key ID**.
Supabase → **Authentication → Providers → Apple** → enable + fill those in.
Full walkthrough: `supabase/README.md` §3.

## 3. LiveKit (10 min)
[cloud.livekit.io](https://cloud.livekit.io) → create project → copy **WebSocket URL**,
**API Key**, **API Secret**. Free tier is fine.

## 4. Edge function (5 min)
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set LIVEKIT_API_KEY=APIxxxx LIVEKIT_API_SECRET=xxxx LIVEKIT_URL=wss://yourproj.livekit.cloud
supabase functions deploy livekit-token
```

## 5. App config (3 min)
```bash
cd ios
cp RideTalk/App/Secrets.example.xcconfig RideTalk/App/Secrets.xcconfig
```
Edit `ios/RideTalk/App/Secrets.xcconfig` — **hosts only, no `https://`** (xcconfig treats
`//` as a comment):
```
SUPABASE_URL_HOST = yourref.supabase.co
SUPABASE_ANON_KEY = eyJ...           ← the anon PUBLIC key
LIVEKIT_URL_HOST  = yourproj.livekit.cloud
```

## 6. Generate the project (2 min)
```bash
brew install xcodegen        # once
cd ios && xcodegen generate
open RideTalk.xcodeproj
```

## 7. Build & run (5 min)
1. Project → target **RideTalk** → **Signing & Capabilities** → pick your **Team**
   (change the bundle ID to something unique if needed).
2. Plug in the iPhone, select it as the destination, **⌘R**.
3. First run: on the phone, Settings → General → VPN & Device Management → trust your
   developer cert → run again.

## ✅ Success looks like
1. App launches to **Sign in with Apple** (not "Backend not configured")
2. Sign in → Home → **Start a ride** → room code appears
3. Grant mic + location (the app explains why before asking)
4. Second iPhone: **Join a ride** with the code
5. Hold **Talk** → the other phone hears you; both appear on the **Map**

## 🆘 Troubleshooting
| Symptom | Likely cause |
|---|---|
| "Backend not configured" card | `Secrets.xcconfig` missing/placeholder → re-run `xcodegen generate` after editing |
| Sign-in fails | Apple provider config (Services ID / key / Team ID) in Supabase |
| "No active ride with that code" | Room ended, or migrations not applied |
| Voice connects but silent | Mic permission denied (Profile → Permissions), or LiveKit secrets wrong |
| Map empty | Location permission — the map overlay tells you |
| `xcodegen: command not found` | `brew install xcodegen` |
