import Link from "next/link";

export function EclipseMark({ className = "" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 28 28"
      aria-hidden="true"
      className={className}
      fill="none"
    >
      <circle cx="14" cy="14" r="9" fill="var(--accent)" />
      <circle cx="18.4" cy="11.2" r="8.1" fill="var(--bg)" />
      <circle
        cx="14"
        cy="14"
        r="12.25"
        stroke="currentColor"
        strokeOpacity="0.28"
        strokeWidth="1.5"
      />
      <circle cx="23.1" cy="6.3" r="1.35" fill="var(--accent)" />
    </svg>
  );
}

export function Logo({ href = "/" }: { href?: string }) {
  return (
    <Link
      href={href}
      className="group flex items-center gap-2.5 rounded-md text-fg outline-none focus-visible:ring-2 focus-visible:ring-accent/70 focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
      aria-label="ArchEclipse home"
    >
      <EclipseMark className="h-6 w-6 shrink-0 text-fg transition-transform duration-300 group-hover:rotate-12" />
      <span className="text-[15px] font-semibold tracking-tight">
        Arch<span className="text-accent">Eclipse</span>
      </span>
      <span className="hidden rounded border border-line px-1.5 py-0.5 font-mono text-[10px] font-medium uppercase tracking-wider text-muted sm:inline">
        Docs
      </span>
    </Link>
  );
}
