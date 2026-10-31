"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { NavGroup } from "@/lib/docs";
import { basePath } from "@/lib/site";

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      viewBox="0 0 16 16"
      aria-hidden="true"
      className={`h-3.5 w-3.5 shrink-0 text-faint transition-transform duration-200 ${
        open ? "rotate-90" : ""
      }`}
      fill="none"
    >
      <path
        d="m6 3.5 4.5 4.5L6 12.5"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function MenuIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <path
        d="M3 5.5h14M3 10h14M3 14.5h14"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

function CloseIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <path
        d="m5 5 10 10M15 5 5 15"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function DocsSidebar({ groups }: { groups: NavGroup[] }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(groups.map((group) => [group.title, true])),
  );
  const triggerRef = useRef<HTMLButtonElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const navRef = useRef<HTMLElement>(null);
  const asideRef = useRef<HTMLElement>(null);

  const normalizedPathname = (() => {
    let value = pathname ?? "/";
    if (basePath && value.startsWith(basePath)) value = value.slice(basePath.length);
    if (value.length > 1) value = value.replace(/\/$/, "");
    return value || "/";
  })();

  const activeGroup = groups.find((group) =>
    group.items.some((item) => item.href === normalizedPathname),
  );

  useEffect(() => {
    if (!activeGroup) return;
    setOpenGroups((current) =>
      current[activeGroup.title] ? current : { ...current, [activeGroup.title]: true },
    );
  }, [activeGroup]);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!mobileOpen) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setMobileOpen(false);
        triggerRef.current?.focus();
        return;
      }

      if (event.key !== "Tab") return;

      const focusable = Array.from(
        asideRef.current?.querySelectorAll<HTMLElement>(
          'a[href]:not([tabindex="-1"]), button:not([disabled]):not([tabindex="-1"])',
        ) ?? [],
      ).filter((element) => element.offsetParent !== null);

      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [mobileOpen]);

  useEffect(() => {
    const active = navRef.current?.querySelector<HTMLElement>('[aria-current="page"]');
    active?.scrollIntoView({ block: "nearest" });
  }, [normalizedPathname]);

  const currentTitle =
    groups.flatMap((group) => group.items).find(
      (item) => item.href === normalizedPathname,
    )?.title ?? "Documentation";

  return (
    <>
      <div className="flex items-center gap-3 border-b border-line px-4 py-2.5 lg:hidden">
        <button
          ref={triggerRef}
          type="button"
          onClick={() => setMobileOpen(true)}
          aria-label="Open documentation navigation"
          aria-expanded={mobileOpen}
          aria-controls="docs-navigation"
          className="flex h-8 w-8 items-center justify-center rounded-md border border-line text-muted outline-none transition-colors hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
        >
          <MenuIcon className="h-4 w-4" />
        </button>
        <span className="truncate text-sm font-medium text-fg">{currentTitle}</span>
      </div>

      {mobileOpen ? (
        <button
          type="button"
          aria-label="Close documentation navigation"
          onClick={() => {
            setMobileOpen(false);
            triggerRef.current?.focus();
          }}
          className="fixed inset-0 z-40 cursor-default bg-black/55 lg:hidden"
          tabIndex={-1}
        />
      ) : null}

      <aside
        ref={asideRef}
        id="docs-navigation"
        className={`fixed inset-y-0 left-0 z-50 flex w-[290px] max-w-[86vw] -translate-x-full flex-col border-r border-line bg-bg transition-transform duration-200 ease-out lg:visible lg:sticky lg:top-14 lg:z-0 lg:h-[calc(100dvh-3.5rem)] lg:w-full lg:translate-x-0 lg:border-r-0 lg:bg-transparent ${
          mobileOpen
            ? "visible translate-x-0 shadow-2xl lg:shadow-none"
            : "invisible"
        }`}
        aria-label="Documentation"
      >
        <div className="flex items-center justify-between border-b border-line px-4 py-3 lg:hidden">
          <span className="text-sm font-semibold text-fg">Documentation</span>
          <button
            ref={closeRef}
            type="button"
            onClick={() => {
              setMobileOpen(false);
              triggerRef.current?.focus();
            }}
            aria-label="Close documentation navigation"
            className="flex h-8 w-8 items-center justify-center rounded-md text-muted outline-none transition-colors hover:bg-surface hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            <CloseIcon className="h-4 w-4" />
          </button>
        </div>

        <nav
          ref={navRef}
          className="flex-1 overflow-y-auto overscroll-contain px-3 py-5 lg:px-4 lg:py-7"
        >
          <Link
            href="/docs"
            aria-current={normalizedPathname === "/docs" ? "page" : undefined}
            className={`mb-5 flex items-center gap-2 rounded-md px-2.5 py-1.5 text-[13px] font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/70 ${
              normalizedPathname === "/docs"
                ? "bg-accent-soft text-accent"
                : "text-muted hover:bg-surface hover:text-fg"
            }`}
          >
            <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
              <path
                d="M2.5 3.5h4a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 0-1.5-1.5h-4v-8Zm11 0h-4A1.5 1.5 0 0 0 8 5v8a1.5 1.5 0 0 1 1.5-1.5h4v-8Z"
                stroke="currentColor"
                strokeWidth="1.25"
                strokeLinejoin="round"
              />
            </svg>
            Documentation home
          </Link>

          <div className="space-y-5">
            {groups.map((group) => {
              const isOpen = openGroups[group.title] ?? true;
              const panelId = `nav-group-${group.title
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, "-")}`;

              return (
                <div key={group.title}>
                  <button
                    type="button"
                    onClick={() =>
                      setOpenGroups((current) => ({
                        ...current,
                        [group.title]: !isOpen,
                      }))
                    }
                    aria-expanded={isOpen}
                    aria-controls={panelId}
                    className="group flex w-full items-center justify-between gap-2 rounded px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.08em] text-faint outline-none transition-colors hover:text-muted focus-visible:ring-2 focus-visible:ring-accent/70"
                  >
                    <span>{group.title}</span>
                    <Chevron open={isOpen} />
                  </button>

                  <div
                    className={`grid transition-[grid-template-rows] duration-200 ease-out ${
                      isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
                    }`}
                  >
                    <div className="overflow-hidden">
                      <ul className="mt-1 space-y-0.5 pb-1" id={panelId}>
                        {group.items.map((item) => {
                          const active = item.href === normalizedPathname;
                          return (
                            <li key={item.href}>
                              <Link
                                href={item.href}
                                aria-current={active ? "page" : undefined}
                                tabIndex={isOpen ? 0 : -1}
                                className={`relative block rounded-md px-2.5 py-1.5 text-[13.5px] leading-snug outline-none transition-colors duration-150 focus-visible:ring-2 focus-visible:ring-accent/70 ${
                                  active
                                    ? "bg-accent-soft font-medium text-accent before:absolute before:top-1.5 before:bottom-1.5 before:left-0 before:w-0.5 before:rounded-full before:bg-accent"
                                    : "text-muted hover:bg-surface hover:text-fg"
                                }`}
                              >
                                {item.title}
                              </Link>
                            </li>
                          );
                        })}
                      </ul>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </nav>
      </aside>
    </>
  );
}
