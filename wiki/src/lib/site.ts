export const site = {
  name: "ArchEclipse",
  title: "ArchEclipse Documentation",
  description:
    "Documentation for ArchEclipse — an opinionated Arch Linux + Hyprland desktop with a Quickshell interface, wallpaper-driven theming and a one-command installer.",
  github: "https://github.com/AymanLyesri/ArchEclipse",
  discord: "https://discord.gg/fMGt4vH6s5",
  issues: "https://github.com/AymanLyesri/ArchEclipse/issues",
} as const;

/**
 * The exported site can live at the domain root or under a GitHub project
 * path. This value must match `basePath` in next.config.ts at build time.
 */
export const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? "").replace(
  /\/+$/,
  "",
);

/** Prefix a site-absolute asset URL (images, files in /public). */
export function withBasePath(path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${basePath}${normalized}`;
}
