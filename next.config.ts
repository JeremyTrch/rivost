import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.pathe.fr" },
      { protocol: "https", hostname: "media.pathe.fr" },
      { protocol: "https", hostname: "**.allocine.fr" },
      { protocol: "https", hostname: "image.tmdb.org" },
      { protocol: "https", hostname: "**.cgrcinemas.fr" },
      { protocol: "https", hostname: "**.api-cinema.com" },
    ],
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
