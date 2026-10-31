"use client";

import { useEffect, useState } from "react";
import type { TocItem } from "@/lib/docs";

function useActiveHeading(items: TocItem[]) {
  const [activeId, setActiveId] = useState<string>("");

  useEffect(() => {
    if (items.length === 0) return;

    const elements = items
      .map((item) => document.getElementById(item.id))
      .filter((element): element is HTMLElement => element !== null);

    let frame = 0;
    const update = () => {
      frame = 0;
      let current = elements[0]?.id ?? "";
      for (const element of elements) {
        if (element.getBoundingClientRect().top <= 140) current = element.id;
        else break;
      }

      // At the bottom of the page the last heading may never cross the
      // threshold, so highlight it once the reader has reached the end.
      if (window.innerHeight + window.scrollY >= document.body.scrollHeight - 40) {
        current = elements[elements.length - 1]?.id ?? current;
      }

      setActiveId(current);
    };

    const onScroll = () => {
      if (frame) return;
      frame = window.requestAnimationFrame(update);
    };

    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, [items]);

  return activeId;
}

export function TableOfContents({ items }: { items: TocItem[] }) {
  const activeId = useActiveHeading(items);

  if (items.length === 0) return null;

  return (
    <aside className="hidden xl:block" aria-label="On this page">
      <div className="sticky top-20 max-h-[calc(100dvh-6rem)] overflow-y-auto pb-8">
        <p className="mb-3 text-[10.5px] font-semibold uppercase tracking-[0.1em] text-faint">
          On this page
        </p>
        <nav>
          <ul className="space-y-0.5 border-l border-line">
            {items.map((item) => {
              const active = item.id === activeId;
              return (
                <li key={item.id}>
                  <a
                    href={`#${item.id}`}
                    aria-current={active ? "location" : undefined}
                    className={`-ml-px block border-l py-1 pr-2 text-[12.5px] leading-snug transition-colors duration-150 ${
                      item.depth === 3 ? "pl-6" : "pl-3.5"
                    } ${
                      active
                        ? "border-accent text-accent"
                        : "border-transparent text-muted hover:border-line-strong hover:text-fg"
                    }`}
                  >
                    {item.text}
                  </a>
                </li>
              );
            })}
          </ul>
        </nav>
      </div>
    </aside>
  );
}

export function MobileTableOfContents({ items }: { items: TocItem[] }) {
  if (items.length === 0) return null;

  return (
    <details className="mb-8 rounded-lg border border-line bg-surface/60 xl:hidden">
      <summary className="flex cursor-pointer list-none items-center justify-between px-4 py-3 text-[13px] font-medium text-fg [&::-webkit-details-marker]:hidden">
        On this page
        <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5 text-faint" fill="none">
          <path d="m4 6 4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </summary>
      <nav className="border-t border-line px-4 py-3" aria-label="On this page">
        <ul className="space-y-1.5">
          {items.map((item) => (
            <li key={item.id} className={item.depth === 3 ? "pl-4" : ""}>
              <a
                href={`#${item.id}`}
                className="block text-[13px] text-muted hover:text-fg"
              >
                {item.text}
              </a>
            </li>
          ))}
        </ul>
      </nav>
    </details>
  );
}
