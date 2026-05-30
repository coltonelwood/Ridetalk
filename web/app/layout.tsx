import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RideTalk — group walkie-talkie for riders",
  description:
    "Talk hands-free with your crew. Group voice, live location, and music sync for scooter riders — over cellular, not Bluetooth range.",
  openGraph: {
    title: "RideTalk",
    description: "Group walkie-talkie + live location + music sync for riders.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
