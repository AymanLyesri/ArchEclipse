import type { Metadata } from "next";
import Link from "next/link";
import { CommandSnippet } from "@/components/command-snippet";
import { EclipseMark } from "@/components/logo";
import { getNavGroups } from "@/lib/docs";
import { site, withBasePath } from "@/lib/site";

export const metadata: Metadata = {
  description: site.description,
};

const INSTALL_COMMAND =
  "python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/install.py)";

export default function HomePage() {
  const groups = getNavGroups().filter((group) => group.title !== "Overview");
  const introduction = getNavGroups()
    .flatMap((group) => group.items)
    .find((item) => item.slug.join("/") === "introduction");

  return (
    <>
      <section className="relative border-b border-line">
        <div className="mx-auto grid max-w-[1200px] gap-12 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[minmax(0,1.08fr)_minmax(0,0.92fr)] lg:items-center lg:py-28">
          <div className="min-w-0">
            <p className="mb-5 flex items-center gap-2 text-[11.5px] font-medium uppercase tracking-[0.12em] text-muted">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-accent" />
              Arch Linux · Hyprland · Quickshell
            </p>

            <h1 className="max-w-[16ch] text-[2.5rem] leading-[1.08] font-semibold tracking-[-0.035em] text-fg sm:text-[3.25rem]">
              A Hyprland desktop, documented end to end.
            </h1>

            <p className="mt-6 max-w-[58ch] text-[15.5px] leading-relaxed text-muted">
              ArchEclipse ships a Lua-configured Hyprland session, a Quickshell
              bar with launcher and side panels, wallpaper-driven colors and a
              one-command installer. These pages describe what is actually in the
              repository — paths, commands and defaults included.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Link
                href="/docs/getting-started/installation"
                className="inline-flex h-10 items-center gap-2 rounded-md bg-accent px-4 text-[13.5px] font-semibold text-accent-fg outline-none transition-colors hover:bg-accent-strong focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
              >
                Install ArchEclipse
                <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
                  <path d="M3.5 8h9m-3.5-3.5L12.5 8 9 11.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </Link>
              <Link
                href="/docs/introduction"
                className="inline-flex h-10 items-center rounded-md border border-line px-4 text-[13.5px] font-medium text-fg outline-none transition-colors hover:border-line-strong hover:bg-surface focus-visible:ring-2 focus-visible:ring-accent/70"
              >
                Read the introduction
              </Link>
            </div>

            <div className="mt-8 max-w-[620px]">
              <p className="mb-2 text-[11px] font-medium uppercase tracking-wider text-faint">
                Official install command
              </p>
              <CommandSnippet command={INSTALL_COMMAND} />
              <p className="mt-2 text-[12px] text-faint">
                Requires Arch Linux (or a close derivative), Hyprland and Python 3.
              </p>
            </div>
          </div>

          <div className="relative min-w-0">
            <div className="rounded-xl border border-line bg-surface p-5 shadow-[0_24px_80px_-48px_rgba(0,0,0,0.45)]">
              <div className="mb-4 flex items-center gap-2 border-b border-line pb-3">
                <span className="h-2 w-2 rounded-full bg-line-strong" />
                <span className="h-2 w-2 rounded-full bg-line-strong" />
                <span className="h-2 w-2 rounded-full bg-accent" />
                <span className="ml-auto font-mono text-[10.5px] text-faint">
                  ~/.config
                </span>
              </div>

              <div className="space-y-3 font-mono text-[12.5px] leading-relaxed">
                <TreeRow name="hypr/" comment="compositor + installer" accent />
                <div className="ml-4 space-y-2 border-l border-line pl-4">
                  <TreeRow name="hyprland.lua" comment="entry point" />
                  <TreeRow name="config/*.lua" comment="bind, decoration, input" />
                  <TreeRow name="config/custom/" comment="machine-local overrides" />
                  <TreeRow name="maintenance/install.py" comment="one-command setup" />
                </div>
                <TreeRow name="quickshell/archeclipse/" comment="bar + panels" accent />
                <div className="ml-4 space-y-2 border-l border-line pl-4">
                  <TreeRow name="shell.qml" comment="shell bootstrap" />
                  <TreeRow name="services/" comment="state + IPC" />
                  <TreeRow name="widgets/" comment="bar, launcher, panels" />
                </div>
                <TreeRow name="wallpapers/" comment="defaults, custom, wallhaven" accent />
              </div>
            </div>

            <div className="absolute -top-4 -right-3 hidden items-center gap-2 rounded-lg border border-line bg-bg px-3 py-2 shadow-lg sm:flex">
              <EclipseMark className="h-4 w-4 text-fg" />
              <span className="font-mono text-[10.5px] text-muted">SUPER + W</span>
              <span className="text-[10.5px] text-faint">wallpapers</span>
            </div>
          </div>
        </div>
      </section>

      <section
        aria-labelledby="overview-video-heading"
        className="border-b border-line"
      >
        <div className="mx-auto max-w-[1200px] px-4 py-16 sm:px-6">
          <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-accent">
                Overview
              </p>
              <h2
                id="overview-video-heading"
                className="mt-1 text-[1.4rem] font-semibold tracking-tight text-fg"
              >
                The desktop, in motion.
              </h2>
              <p className="mt-1 max-w-[68ch] text-[13.5px] leading-relaxed text-muted">
                A 22-second tour of the bar, launcher, side panels, wallpaper
                picker and wallpaper-driven theming.
              </p>
            </div>
            <span className="font-mono text-[11px] text-faint">00:22</span>
          </div>

          <figure>
            <div className="overflow-hidden rounded-xl border border-line bg-black shadow-[0_24px_80px_-48px_rgba(0,0,0,0.5)]">
              <video
                className="aspect-video w-full"
                controls
                muted
                playsInline
                preload="metadata"
                poster={withBasePath("/images/overview-poster.webp")}
                aria-label="ArchEclipse desktop overview"
              >
                <source
                  src={withBasePath("/media/overview.mp4")}
                  type="video/mp4"
                />
                Your browser does not support the video element. The overview
                shows the ArchEclipse bar, launcher, side panels and wallpaper
                picker.
              </video>
            </div>
            <figcaption className="mt-3 text-[12px] text-faint">
              Click play to view the recording. Audio is muted by default.
            </figcaption>
          </figure>
        </div>
      </section>

      <section aria-labelledby="explore-heading" className="mx-auto max-w-[1200px] px-4 py-16 sm:px-6">
        <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
          <div>
            <h2 id="explore-heading" className="text-[1.4rem] font-semibold tracking-tight text-fg">
              Explore the documentation
            </h2>
            <p className="mt-1 text-[13.5px] text-muted">
              Start with installation, then work through configuration and theming.
            </p>
          </div>
          <Link
            href="/docs"
            className="rounded text-[13px] font-medium text-accent outline-none hover:text-accent-strong focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            All documentation →
          </Link>
        </div>

        {introduction ? (
          <Link
            href={introduction.href}
            className="group mb-4 flex flex-col justify-between gap-4 rounded-xl border border-line bg-surface/70 p-6 outline-none transition-colors hover:border-line-strong hover:bg-surface focus-visible:ring-2 focus-visible:ring-accent/70 sm:flex-row sm:items-center"
          >
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-accent">
                Start here
              </p>
              <h3 className="mt-1 text-[17px] font-semibold text-fg">
                {introduction.title}
              </h3>
              <p className="mt-1 max-w-[76ch] text-[13.5px] leading-relaxed text-muted">
                {introduction.description}
              </p>
            </div>
            <span className="shrink-0 rounded-md border border-line px-3 py-1.5 text-[12px] font-medium text-muted transition-colors group-hover:border-accent/40 group-hover:text-accent">
              Read introduction
            </span>
          </Link>
        ) : null}

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {groups.map((group) => (
            <div key={group.title} className="rounded-xl border border-line p-5">
              <h3 className="text-[12px] font-semibold uppercase tracking-[0.09em] text-faint">
                {group.title}
              </h3>
              <ul className="mt-3 space-y-2.5">
                {group.items.slice(0, 6).map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className="group flex items-start justify-between gap-3 text-[13.5px] text-muted outline-none transition-colors hover:text-fg focus-visible:text-fg"
                    >
                      <span>{item.title}</span>
                      <span
                        aria-hidden="true"
                        className="mt-0.5 text-faint transition-transform duration-150 group-hover:translate-x-0.5 group-hover:text-accent"
                      >
                        →
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-line bg-surface/50">
        <div className="mx-auto flex max-w-[1200px] flex-col gap-4 px-4 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div>
            <h2 className="text-[15px] font-semibold text-fg">
              Need help or have something to add?
            </h2>
            <p className="mt-1 text-[13px] text-muted">
              The Discord is the fastest place to get help. Bugs and documentation
              corrections belong in GitHub issues.
            </p>
          </div>
          <div className="flex shrink-0 flex-wrap gap-2">
            <a
              href={site.discord}
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-9 items-center rounded-md bg-accent px-3.5 text-[12.5px] font-semibold text-accent-fg transition-colors hover:bg-accent-strong"
            >
              Join Discord
            </a>
            <a
              href={site.issues}
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-9 items-center rounded-md border border-line bg-bg px-3.5 text-[12.5px] font-medium text-fg transition-colors hover:border-line-strong"
            >
              Open an issue
            </a>
          </div>
        </div>
      </section>
    </>
  );
}

function TreeRow({
  name,
  comment,
  accent = false,
}: {
  name: string;
  comment: string;
  accent?: boolean;
}) {
  return (
    <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5">
      <span className={accent ? "text-accent" : "text-fg"}>{name}</span>
      <span className="text-[11px] text-faint">{comment}</span>
    </div>
  );
}
