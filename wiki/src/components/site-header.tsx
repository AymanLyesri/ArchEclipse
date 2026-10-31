import Link from "next/link";
import { Logo } from "@/components/logo";
import { SearchDialog } from "@/components/search-dialog";
import { ThemeToggle } from "@/components/theme-toggle";
import { site } from "@/lib/site";

function GitHubIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className={className}
      fill="currentColor"
    >
      <path d="M12 .7a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2.16c-3.2.7-3.88-1.36-3.88-1.36-.53-1.33-1.28-1.68-1.28-1.68-1.05-.72.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.7 1.25 3.36.96.1-.75.4-1.25.73-1.54-2.56-.29-5.25-1.28-5.25-5.68 0-1.26.45-2.28 1.18-3.09-.12-.29-.51-1.46.11-3.05 0 0 .96-.31 3.16 1.18a10.9 10.9 0 0 1 5.76 0c2.19-1.49 3.15-1.18 3.15-1.18.63 1.59.24 2.76.12 3.05.74.81 1.18 1.83 1.18 3.09 0 4.41-2.7 5.38-5.27 5.67.42.36.78 1.07.78 2.16v3.2c0 .32.21.67.8.56A11.5 11.5 0 0 0 12 .7Z" />
    </svg>
  );
}

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-30 h-14 border-b border-line bg-bg">
      <div className="mx-auto flex h-full max-w-[1440px] items-center gap-4 px-4 sm:px-6">
        <Logo />

        <nav
          aria-label="Main"
          className="ml-2 hidden items-center gap-1 text-[13px] md:flex"
        >
          <Link
            href="/docs"
            className="rounded-md px-2.5 py-1.5 text-muted outline-none transition-colors hover:bg-surface hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            Documentation
          </Link>
          <Link
            href="/docs/getting-started/installation"
            className="rounded-md px-2.5 py-1.5 text-muted outline-none transition-colors hover:bg-surface hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            Install
          </Link>
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <SearchDialog />
          <ThemeToggle />
          <a
            href={site.github}
            target="_blank"
            rel="noreferrer"
            aria-label="ArchEclipse on GitHub"
            title="GitHub repository"
            className="flex h-8 items-center gap-2 rounded-md px-2 text-muted outline-none transition-colors hover:bg-surface hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            <GitHubIcon className="h-4 w-4" />
            <span className="hidden text-[13px] lg:inline">GitHub</span>
          </a>
        </div>
      </div>
    </header>
  );
}
