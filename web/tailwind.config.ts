import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ride: {
          bg: "#0a0d12",
          surface: "#191e26",
          accent: "#2ef28d",
          talk: "#33ccff",
          danger: "#fa3b4d",
        },
      },
    },
  },
  plugins: [],
};

export default config;
