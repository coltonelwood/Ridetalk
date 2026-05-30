const APP_STORE_URL =
  process.env.NEXT_PUBLIC_APP_STORE_URL ?? "#";

const features = [
  {
    icon: "🎙️",
    title: "Group walkie-talkie",
    body: "Low-latency push-to-talk or hands-free voice for your whole crew. Works with AirPods.",
  },
  {
    icon: "📍",
    title: "Live location",
    body: "See every rider on one map. Stay together even when you spread out.",
  },
  {
    icon: "🆘",
    title: "Emergency button",
    body: "One tap alerts your group and shares your location when something goes wrong.",
  },
  {
    icon: "🎵",
    title: "Music sync",
    body: "Share a track link — everyone listens together in their own app. Fully compliant.",
  },
  {
    icon: "📶",
    title: "Real range",
    body: "Runs over cellular/WiFi, not Bluetooth. Talk city-to-city, not just curb-to-curb.",
  },
  {
    icon: "🛴",
    title: "Built for riding",
    body: "Huge buttons, minimal taps, background audio. Glance, don't fiddle.",
  },
];

export default function Home() {
  return (
    <main className="mx-auto max-w-5xl px-6">
      {/* Hero */}
      <section className="flex flex-col items-center text-center pt-24 pb-20">
        <div className="text-6xl mb-4">📡</div>
        <h1 className="text-5xl sm:text-7xl font-black tracking-tight">
          Ride<span className="text-ride-accent">Talk</span>
        </h1>
        <p className="mt-6 max-w-xl text-lg sm:text-xl text-gray-300">
          A walkie-talkie for scooter crews. Talk hands-free on AirPods, share live
          location, and sync music — connected over cellular, not Bluetooth range.
        </p>
        <div className="mt-10 flex flex-wrap gap-4 justify-center">
          <a
            href={APP_STORE_URL}
            className="rounded-xl bg-ride-accent px-8 py-4 font-bold text-black hover:opacity-90 transition"
          >
            Download for iPhone
          </a>
          <a
            href="#how"
            className="rounded-xl border border-white/15 px-8 py-4 font-semibold hover:bg-white/5 transition"
          >
            How it works
          </a>
        </div>
        <p className="mt-4 text-sm text-gray-500">
          iPhone first · Sign in with Apple · AirPods ready
        </p>
      </section>

      {/* Features */}
      <section className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 pb-20">
        {features.map((f) => (
          <div
            key={f.title}
            className="rounded-2xl bg-ride-surface p-6 border border-white/5"
          >
            <div className="text-3xl mb-3">{f.icon}</div>
            <h3 className="text-lg font-bold">{f.title}</h3>
            <p className="mt-2 text-sm text-gray-400">{f.body}</p>
          </div>
        ))}
      </section>

      {/* How it works */}
      <section id="how" className="pb-20">
        <h2 className="text-3xl font-bold text-center mb-10">How it works</h2>
        <ol className="grid gap-6 sm:grid-cols-3">
          {[
            ["1", "Start a ride", "Create a room and share the code or invite link."],
            ["2", "Crew joins", "Tap the link, pop in AirPods, you're connected."],
            ["3", "Ride & talk", "Hold to talk, see everyone on the map, sync the music."],
          ].map(([n, t, b]) => (
            <li key={n} className="rounded-2xl bg-ride-surface p-6 border border-white/5">
              <div className="text-ride-talk text-2xl font-black">{n}</div>
              <h3 className="mt-2 font-bold">{t}</h3>
              <p className="mt-1 text-sm text-gray-400">{b}</p>
            </li>
          ))}
        </ol>
      </section>

      {/* Compliance note */}
      <section className="pb-24">
        <div className="rounded-2xl border border-white/10 p-6 text-sm text-gray-400">
          <p>
            <span className="font-semibold text-gray-200">About music: </span>
            RideTalk never captures or rebroadcasts Apple Music or Spotify audio. It syncs
            the track and play position so everyone listens together in their own app —
            keeping things within each platform&apos;s rules.
          </p>
          <p className="mt-3">
            <span className="font-semibold text-gray-200">Ride safe: </span>
            RideTalk is a communication aid, not a substitute for safe riding. The emergency
            button alerts your group — it does not contact emergency services. Check your
            local laws on earbuds while riding.
          </p>
        </div>
      </section>

      <footer className="border-t border-white/10 py-10 text-center text-sm text-gray-500">
        © {new Date().getFullYear()} RideTalk · Built with SwiftUI, Supabase &amp; LiveKit
      </footer>
    </main>
  );
}
