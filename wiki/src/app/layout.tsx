import type { Metadata, Viewport } from "next";
import "@fontsource-variable/inter";
import "@fontsource-variable/jetbrains-mono";
import "@/app/globals.css";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { ThemeScript } from "@/components/theme-script";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: {
    default: site.title,
    template: `%s · ${site.name} Docs`,
  },
  description: site.description,
  applicationName: site.name,
  authors: [{ name: "Ayman Lyesri", url: site.github }],
  keywords: [
    "ArchEclipse",
    "Hyprland",
    "Arch Linux",
    "Quickshell",
    "Wayland",
    "dotfiles",
  ],
  openGraph: {
    title: site.title,
    description: site.description,
    type: "website",
    siteName: site.title,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fcfbf8" },
    { media: "(prefers-color-scheme: dark)", color: "#0a0e13" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <ThemeScript />
      </head>
      <body className="flex min-h-dvh flex-col">
        <a
          href="#main-content"
          className="sr-only z-50 rounded-md bg-bg px-3 py-2 text-sm font-medium text-fg focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:ring-2 focus:ring-accent"
        >
          Skip to content
        </a>
        <SiteHeader />
        <main id="main-content" className="flex-1">
          {children}
        </main>
        <SiteFooter />
      </body>
    </html>
  );
}
