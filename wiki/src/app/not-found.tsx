import Link from "next/link";
import { EclipseMark } from "@/components/logo";

export default function NotFound() {
  return (
    <div
      data-pagefind-ignore
      className="mx-auto flex max-w-[640px] flex-col items-start px-4 py-24 sm:px-6"
    >
      <EclipseMark className="h-8 w-8 text-fg" />
      <p className="mt-6 font-mono text-[11px] uppercase tracking-[0.12em] text-faint">
        404
      </p>
      <h1 className="mt-2 text-[2rem] font-semibold tracking-tight text-fg">
        Page not found
      </h1>
      <p className="mt-3 text-[14.5px] leading-relaxed text-muted">
        This page does not exist in the documentation. Try the documentation
        index, or search with{" "}
        <kbd className="rounded border border-line bg-surface px-1.5 py-0.5 font-mono text-[11px]">
          Ctrl K
        </kbd>
        .
      </p>
      <div className="mt-6 flex gap-3">
        <Link
          href="/docs"
          className="inline-flex h-9 items-center rounded-md bg-accent px-3.5 text-[13px] font-semibold text-accent-fg transition-colors hover:bg-accent-strong"
        >
          Documentation
        </Link>
        <Link
          href="/"
          className="inline-flex h-9 items-center rounded-md border border-line px-3.5 text-[13px] font-medium text-fg transition-colors hover:border-line-strong"
        >
          Home
        </Link>
      </div>
    </div>
  );
}
