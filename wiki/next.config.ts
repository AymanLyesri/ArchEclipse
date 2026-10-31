import type { NextConfig } from "next";

/**
 * GitHub Pages deployments serve from a project sub-path (for example
 * `/ArchEclipse`). Set NEXT_PUBLIC_BASE_PATH at build time to that sub-path.
 * Leave it empty for local development or a user/root Pages site.
 */
const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? "").replace(/\/+$/, "");

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  basePath,
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
