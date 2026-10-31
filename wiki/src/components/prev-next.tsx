import Link from "next/link";
import type { NavItem } from "@/lib/docs";

export function PrevNext({
  previous,
  next,
}: {
  previous: NavItem | null;
  next: NavItem | null;
}) {
  if (!previous && !next) return null;

  return (
    <nav
      aria-label="Previous and next documentation pages"
      className="mt-14 grid gap-3 border-t border-line pt-6 sm:grid-cols-2"
    >
      {previous ? (
        <Link
          href={previous.href}
          className="group rounded-lg border border-line p-4 outline-none transition-colors hover:border-line-strong hover:bg-surface focus-visible:ring-2 focus-visible:ring-accent/70"
        >
          <span className="block text-[11px] font-medium uppercase tracking-wider text-faint">
            Previous
          </span>
          <span className="mt-1 block text-[13.5px] font-medium text-fg transition-colors group-hover:text-accent">
            {previous.title}
          </span>
        </Link>
      ) : (
        <span className="hidden sm:block" />
      )}

      {next ? (
        <Link
          href={next.href}
          className="group rounded-lg border border-line p-4 text-right outline-none transition-colors hover:border-line-strong hover:bg-surface focus-visible:ring-2 focus-visible:ring-accent/70"
        >
          <span className="block text-[11px] font-medium uppercase tracking-wider text-faint">
            Next
          </span>
          <span className="mt-1 block text-[13.5px] font-medium text-fg transition-colors group-hover:text-accent">
            {next.title}
          </span>
        </Link>
      ) : null}
    </nav>
  );
}
