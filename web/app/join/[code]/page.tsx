// Universal-link landing for invite links: /join/<CODE>.
// Tries to open the app via the custom scheme, and offers the App Store as a fallback.

const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL ?? "#";

export default function JoinPage({ params }: { params: { code: string } }) {
  const code = (params.code ?? "").toUpperCase();
  const deepLink = `ridetalk://join/${code}`;

  return (
    <main className="mx-auto max-w-md px-6 min-h-screen flex flex-col items-center justify-center text-center">
      <div className="text-5xl mb-4">📡</div>
      <h1 className="text-3xl font-black">Join the ride</h1>
      <p className="mt-3 text-gray-400">You&apos;ve been invited to a RideTalk room.</p>

      <div className="mt-8 w-full rounded-2xl bg-ride-surface p-6 border border-white/5">
        <div className="text-sm text-gray-400">Room code</div>
        <div className="mt-1 text-4xl font-mono font-black tracking-widest text-ride-accent">
          {code || "------"}
        </div>
      </div>

      <a
        href={deepLink}
        className="mt-8 w-full rounded-xl bg-ride-accent px-6 py-4 font-bold text-black hover:opacity-90 transition"
      >
        Open in RideTalk
      </a>
      <a
        href={APP_STORE_URL}
        className="mt-3 w-full rounded-xl border border-white/15 px-6 py-4 font-semibold hover:bg-white/5 transition"
      >
        Get the app
      </a>

      <p className="mt-6 text-xs text-gray-500">
        Don&apos;t have the app yet? Install it, then enter code{" "}
        <span className="font-mono text-gray-300">{code}</span> on the home screen.
      </p>

      {/* Best-effort auto-open on mobile. */}
      <script
        dangerouslySetInnerHTML={{
          __html: `setTimeout(function(){ try { window.location.href = ${JSON.stringify(
            deepLink
          )}; } catch (e) {} }, 400);`,
        }}
      />
    </main>
  );
}
