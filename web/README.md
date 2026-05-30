# RideTalk — Web (landing + invite links)

Next.js (App Router) + Tailwind. Two responsibilities for the MVP:

1. **Landing page** (`/`) — explains the app, links to the App Store.
2. **Invite link handler** (`/join/[code]`) — resolves `https://ridetalk.app/join/<CODE>`
   universal links, tries to open the app via `ridetalk://join/<CODE>`, and offers the App
   Store as a fallback.

A fuller **admin dashboard** (manage groups, ride history, moderation) is a Phase 3 item —
see `docs/ROADMAP.md`.

## Run

```bash
cd web
npm install
cp .env.example .env.local     # add Supabase URL + anon key + App Store URL
npm run dev                    # http://localhost:3000
```

## Universal links (to make https invite links open the app)

1. Host an [`apple-app-site-association`](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
   file at `https://ridetalk.app/.well-known/apple-app-site-association` for the `/join/*`
   paths.
2. Add the **Associated Domains** capability (`applinks:ridetalk.app`) to the iOS app.
3. Until then, the `ridetalk://join/<CODE>` custom scheme works for users who already have
   the app installed.

## Deploy

Any Next.js host (Vercel recommended). Set the same env vars in the host's dashboard.
