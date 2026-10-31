import Link from "next/link";

export function Breadcrumbs({
  group,
  title,
}: {
  group?: string;
  title?: string;
}) {
  return (
    <nav aria-label="Breadcrumb" className="mb-6">
      <ol className="flex flex-wrap items-center gap-1.5 text-[12.5px] text-faint">
        <li>
          <Link
            href="/docs"
            className="rounded-sm outline-none transition-colors hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            Docs
          </Link>
        </li>
        {group ? (
          <>
            <li aria-hidden="true">/</li>
            <li className="text-muted">{group}</li>
          </>
        ) : null}
        {title ? (
          <>
            <li aria-hidden="true">/</li>
            <li aria-current="page" className="text-muted">
              {title}
            </li>
          </>
        ) : null}
      </ol>
    </nav>
  );
}
