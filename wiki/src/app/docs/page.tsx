import type { Metadata } from "next";
import Link from "next/link";
import { Breadcrumbs } from "@/components/breadcrumbs";
import { MobileTableOfContents } from "@/components/table-of-contents";
import { getDocs, getNavGroups } from "@/lib/docs";

export const metadata: Metadata = {
  title: "Documentation",
  description:
    "Every ArchEclipse guide: installation, first boot, configuration, widgets, theming and troubleshooting.",
};

export default function DocsIndexPage() {
  const groups = getNavGroups();
  const total = getDocs().length;

  return (
    <div className="px-5 py-8 sm:px-8 lg:px-10 lg:py-12">
      <div className="mx-auto max-w-[980px]">
        <Breadcrumbs />

        <header className="mb-10 border-b border-line pb-8">
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-accent">
            ArchEclipse
          </p>
          <h1 className="text-[2.25rem] leading-tight font-semibold tracking-[-0.025em] text-fg">
            Documentation
          </h1>
          <p className="mt-3 max-w-[68ch] text-[15px] leading-relaxed text-muted">
            {total} pages covering the installer, Hyprland configuration, the
            Quickshell bar and panels, wallpaper-driven theming and recovery when
            something goes wrong.
          </p>
        </header>

        <div className="space-y-12" data-pagefind-body>
          {groups.map((group) => (
            <section key={group.title} aria-labelledby={`group-${slugify(group.title)}`}>
              <div className="mb-4 flex items-baseline justify-between gap-4">
                <h2
                  id={`group-${slugify(group.title)}`}
                  className="text-[13px] font-semibold uppercase tracking-[0.09em] text-fg"
                >
                  {group.title}
                </h2>
                <span className="font-mono text-[11px] text-faint">
                  {String(group.items.length).padStart(2, "0")}
                </span>
              </div>

              <div className="grid gap-2 sm:grid-cols-2">
                {group.items.map((item) => (
                  <Link
                    key={item.href}
                    href={item.href}
                    className="group flex flex-col rounded-lg border border-line bg-bg p-4 outline-none transition-colors hover:border-line-strong hover:bg-surface focus-visible:ring-2 focus-visible:ring-accent/70"
                  >
                    <span className="flex items-center justify-between gap-3">
                      <span className="text-[14px] font-medium text-fg transition-colors group-hover:text-accent">
                        {item.title}
                      </span>
                      <svg
                        viewBox="0 0 16 16"
                        aria-hidden="true"
                        className="h-3.5 w-3.5 shrink-0 text-faint transition-transform duration-150 group-hover:translate-x-0.5 group-hover:text-accent"
                        fill="none"
                      >
                        <path
                          d="M3.5 8h9m-3.5-3.5L12.5 8 9 11.5"
                          stroke="currentColor"
                          strokeWidth="1.4"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                    </span>
                    {item.description ? (
                      <span className="mt-1 line-clamp-2 text-[12.5px] leading-relaxed text-muted">
                        {item.description}
                      </span>
                    ) : null}
                  </Link>
                ))}
              </div>
            </section>
          ))}
        </div>

        <MobileTableOfContents
          items={groups.map((group) => ({
            id: `group-${slugify(group.title)}`,
            text: group.title,
            depth: 2 as const,
          }))}
        />
      </div>
    </div>
  );
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-");
}
