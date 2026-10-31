import Link from "next/link";
import { EclipseMark } from "@/components/logo";
import { site } from "@/lib/site";

export function SiteFooter() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-5 px-4 py-8 text-[12.5px] text-faint sm:px-6 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2.5">
          <EclipseMark className="h-4 w-4 text-fg" />
          <span>
            <span className="font-medium text-muted">ArchEclipse</span>{" "}
            documentation · GPL-3.0
          </span>
        </div>

        <nav aria-label="Project links" className="flex flex-wrap items-center gap-x-5 gap-y-2">
          <Link href="/docs" className="transition-colors hover:text-fg">
            Docs
          </Link>
          <a
            href={site.github}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-fg"
          >
            GitHub
          </a>
          <a
            href={site.discord}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-fg"
          >
            Discord
          </a>
          <a
            href={site.issues}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-fg"
          >
            Issues
          </a>
        </nav>
      </div>
    </footer>
  );
}
