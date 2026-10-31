"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { basePath, withBasePath } from "@/lib/site";

type PagefindData = {
  url: string;
  excerpt: string;
  meta?: { title?: string; [key: string]: string | undefined };
};

type PagefindResult = {
  data: () => Promise<PagefindData>;
};

type Pagefind = {
  search: (query: string) => Promise<{ results: PagefindResult[] } | null>;
};

type SearchResult = PagefindData & { href: string; title: string };

const QUICK_LINKS = [
  { title: "Getting Started", href: "/docs/getting-started" },
  { title: "Installation", href: "/docs/getting-started/installation" },
  { title: "Configuration", href: "/docs/configuration" },
  { title: "Keyboard Shortcuts", href: "/docs/configuration/keyboard-shortcuts" },
];

function normalizeUrl(url: string): string {
  if (/^https?:\/\//.test(url)) return url;
  if (basePath && url.startsWith(`${basePath}/`)) return url;
  return withBasePath(url);
}

function normalizeTitle(title: string | undefined, url: string): string {
  if (!title) return url;
  return title.replace(/\s*[·|—-]\s*ArchEclipse Documentation\s*$/i, "").trim();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function Highlight({ text, query }: { text: string; query: string }) {
  const tokens = [...new Set(query.trim().split(/\s+/).filter((token) => token.length > 1))];
  if (tokens.length === 0) return <>{text}</>;

  const pattern = new RegExp(`(${tokens.map(escapeRegExp).join("|")})`, "gi");
  const parts = text.split(pattern);
  const lowercaseTokens = new Set(tokens.map((token) => token.toLowerCase()));

  return (
    <>
      {parts.map((part, index) =>
        lowercaseTokens.has(part.toLowerCase()) ? (
          <mark key={index} className="rounded-sm bg-accent/25 px-0.5 text-inherit">
            {part}
          </mark>
        ) : (
          <span key={index}>{part}</span>
        ),
      )}
    </>
  );
}

function SearchIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <circle cx="8.75" cy="8.75" r="5.5" stroke="currentColor" strokeWidth="1.5" />
      <path d="m13 13 3.5 3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

export function SearchDialog() {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const pagefindRef = useRef<Pagefind | null>(null);
  const loadStartedRef = useRef(false);
  const requestRef = useRef(0);
  const optionRefs = useRef<(HTMLLIElement | null)[]>([]);

  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [status, setStatus] = useState<"idle" | "loading" | "ready" | "unavailable">("idle");
  const [pagefindReady, setPagefindReady] = useState(false);
  const [isMac, setIsMac] = useState(false);

  const openSearch = useCallback(() => setOpen(true), []);

  useEffect(() => {
    setIsMac(/Mac|iPhone|iPad|iPod/i.test(navigator.platform));
  }, []);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (open) {
      if (!dialog.open) dialog.showModal();
      window.setTimeout(() => inputRef.current?.focus(), 20);
    } else if (dialog.open) {
      dialog.close();
    }
  }, [open]);

  useEffect(() => {
    if (!open) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      const modifier = event.metaKey || event.ctrlKey;
      if (modifier && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpen((value) => !value);
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!open || loadStartedRef.current) return;
    loadStartedRef.current = true;

    async function loadPagefind() {
      try {
        // Pagefind is generated after `next build`, outside the bundler.
        const dynamicImport = new Function(
          "url",
          "return import(url)",
        ) as (url: string) => Promise<Pagefind>;
        const pagefind = await dynamicImport(withBasePath("/pagefind/pagefind.js"));
        pagefindRef.current = pagefind;
        setStatus("ready");
        setPagefindReady(true);
      } catch {
        setStatus("unavailable");
      }
    }

    void loadPagefind();
  }, [open]);

  useEffect(() => {
    if (!open) return;

    const trimmed = query.trim();
    if (!trimmed) {
      setResults([]);
      setActiveIndex(0);
      setStatus((value) => (value === "unavailable" ? value : "idle"));
      return;
    }

    if (!pagefindReady || !pagefindRef.current) return;

    setStatus("loading");
    const requestId = ++requestRef.current;

    const timer = window.setTimeout(async () => {
      try {
        const response = await pagefindRef.current?.search(trimmed);
        if (requestId !== requestRef.current) return;

        const raw = response?.results.slice(0, 8) ?? [];
        const data = await Promise.all(raw.map((result) => result.data()));
        if (requestId !== requestRef.current) return;

        setResults(
          data.map((item) => {
            const href = normalizeUrl(item.url);
            return {
              ...item,
              href,
              title: normalizeTitle(item.meta?.title, href),
            };
          }),
        );
        setActiveIndex(0);
        setStatus("ready");
      } catch {
        if (requestId === requestRef.current) {
          setResults([]);
          setStatus("unavailable");
        }
      }
    }, 110);

    return () => window.clearTimeout(timer);
  }, [query, open, pagefindReady]);

  useEffect(() => {
    optionRefs.current[activeIndex]?.scrollIntoView({ block: "nearest" });
  }, [activeIndex, results]);

  function closeSearch() {
    setOpen(false);
  }

  function goTo(href: string) {
    setOpen(false);
    window.location.assign(href);
  }

  function onInputKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      if (results.length) setActiveIndex((index) => (index + 1) % results.length);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      if (results.length) {
        setActiveIndex((index) => (index - 1 + results.length) % results.length);
      }
    } else if (event.key === "Home" && results.length) {
      event.preventDefault();
      setActiveIndex(0);
    } else if (event.key === "End" && results.length) {
      event.preventDefault();
      setActiveIndex(results.length - 1);
    } else if (event.key === "Enter") {
      event.preventDefault();
      if (results[activeIndex]) goTo(results[activeIndex].href);
    } else if (event.key === "Escape") {
      event.preventDefault();
      closeSearch();
    }
  }

  const listboxId = "site-search-results";
  const optionId = (index: number) => `site-search-option-${index}`;
  const showResults = query.trim().length > 0 && results.length > 0;

  return (
    <>
      <button
        type="button"
        onClick={openSearch}
        aria-label="Search documentation"
        aria-haspopup="dialog"
        className="group flex h-8 items-center gap-2 rounded-md border border-line bg-surface px-2.5 text-sm text-muted outline-none transition-colors hover:border-line-strong hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70 sm:w-56 lg:w-64"
      >
        <SearchIcon className="h-4 w-4 shrink-0" />
        <span className="hidden flex-1 text-left sm:inline">Search docs</span>
        <span className="flex-1 text-left sm:hidden">Search</span>
        <kbd className="hidden shrink-0 rounded border border-line bg-bg px-1.5 py-0.5 font-mono text-[10px] leading-none text-muted group-hover:text-fg sm:inline">
          {isMac ? "⌘ K" : "Ctrl K"}
        </kbd>
      </button>

      <dialog
        ref={dialogRef}
        aria-label="Search documentation"
        onClose={() => {
          // A rapid Escape → Ctrl+K can reopen the dialog before the native
          // close event lands; only sync state when the dialog is really shut.
          if (!dialogRef.current?.open) setOpen(false);
        }}
        onCancel={() => setOpen(false)}
        onClick={(event) => {
          if (event.target === dialogRef.current) closeSearch();
        }}
        className="search-dialog"
      >
        <div
          className="search-panel"
          onClick={(event) => event.stopPropagation()}
        >
          <div className="flex items-center gap-3 border-b border-line px-4">
            <SearchIcon className="h-4 w-4 shrink-0 text-muted" />
            <input
              ref={inputRef}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={onInputKeyDown}
              type="text"
              role="combobox"
              aria-expanded={showResults}
              aria-controls={listboxId}
              aria-autocomplete="list"
              aria-activedescendant={
                showResults ? optionId(activeIndex) : undefined
              }
              aria-label="Search documentation"
              placeholder="Search the documentation…"
              autoComplete="off"
              spellCheck={false}
              className="h-12 w-full bg-transparent text-[15px] text-fg placeholder:text-faint focus:outline-none"
            />
            <button
              type="button"
              onClick={closeSearch}
              className="hidden rounded border border-line px-1.5 py-0.5 font-mono text-[10px] text-muted hover:text-fg sm:block"
            >
              Esc
            </button>
          </div>

          <div className="max-h-[min(58vh,440px)] overflow-y-auto overscroll-contain p-2">
            {status === "unavailable" ? (
              <p className="px-3 py-8 text-center text-sm text-muted">
                The search index is not available. Build the site with{" "}
                <code className="rounded bg-surface px-1 py-0.5 font-mono text-[12px] text-fg">
                  npm run build
                </code>{" "}
                and serve the exported <code className="font-mono text-[12px] text-fg">out/</code> directory.
              </p>
            ) : query.trim() === "" ? (
              <div className="px-2 py-2">
                <p className="px-2 pb-2 text-[11px] font-medium uppercase tracking-wider text-faint">
                  Common pages
                </p>
                <ul className="space-y-0.5">
                  {QUICK_LINKS.map((link) => (
                    <li key={link.href}>
                      <button
                        type="button"
                        onClick={() => goTo(withBasePath(link.href))}
                        className="flex w-full items-center justify-between rounded-md px-2.5 py-2 text-left text-sm text-muted transition-colors hover:bg-surface hover:text-fg focus-visible:bg-surface focus-visible:text-fg focus-visible:outline-none"
                      >
                        <span>{link.title}</span>
                        <span className="font-mono text-[11px] text-faint">↗</span>
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            ) : status === "loading" && results.length === 0 ? (
              <p className="px-3 py-8 text-center text-sm text-muted">Searching…</p>
            ) : results.length === 0 && status !== "loading" ? (
              <p className="px-3 py-8 text-center text-sm text-muted">
                No results for <span className="text-fg">“{query.trim()}”</span>.
                Try a shorter term or a different spelling.
              </p>
            ) : (
              <ul
                id={listboxId}
                role="listbox"
                aria-label="Search results"
                className="space-y-0.5"
              >
                {results.map((result, index) => (
                  <li
                    key={result.href}
                    id={optionId(index)}
                    role="option"
                    aria-selected={index === activeIndex}
                    ref={(element) => {
                      optionRefs.current[index] = element;
                    }}
                    onMouseMove={() => setActiveIndex(index)}
                    onClick={() => goTo(result.href)}
                    className={`cursor-pointer rounded-md px-3 py-2.5 transition-colors ${
                      index === activeIndex ? "bg-accent-soft" : "hover:bg-surface"
                    }`}
                  >
                    <span className="flex items-center gap-2 text-sm font-medium text-fg">
                      <Highlight text={result.title} query={query} />
                    </span>
                    {result.excerpt ? (
                      <span
                        className="search-excerpt mt-1 block text-[13px] leading-relaxed text-muted"
                        dangerouslySetInnerHTML={{ __html: result.excerpt }}
                      />
                    ) : null}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="flex items-center justify-between gap-4 border-t border-line px-4 py-2.5 text-[11px] text-faint">
            <span className="flex items-center gap-2">
              <kbd className="search-key">↑</kbd>
              <kbd className="search-key">↓</kbd>
              to navigate
            </span>
            <span className="flex items-center gap-2">
              <kbd className="search-key">↵</kbd>
              to open
              <span className="mx-1 h-3 w-px bg-line" />
              <kbd className="search-key">esc</kbd>
              to close
            </span>
          </div>
        </div>
      </dialog>
    </>
  );
}
