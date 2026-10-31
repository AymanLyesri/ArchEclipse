"use client";

import { useEffect, useRef, useState } from "react";

type ThemeMode = "system" | "dark" | "light";

const STORAGE_KEY = "archeclipse-theme";
const MODES: { mode: ThemeMode; label: string }[] = [
  { mode: "system", label: "System theme" },
  { mode: "dark", label: "Dark theme" },
  { mode: "light", label: "Light theme" },
];

function isThemeMode(value: string | null): value is ThemeMode {
  return value === "system" || value === "dark" || value === "light";
}

function applyTheme(mode: ThemeMode) {
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  const dark = mode === "dark" || (mode === "system" && media.matches);
  const root = document.documentElement;

  root.classList.toggle("dark", dark);
  root.dataset.theme = dark ? "dark" : "light";
  root.dataset.themeMode = mode;
  root.style.colorScheme = dark ? "dark" : "light";
}

function SystemIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <rect x="2.75" y="4" width="14.5" height="10" rx="1.75" stroke="currentColor" strokeWidth="1.5" />
      <path d="M7 17h6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function SunIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <circle cx="10" cy="10" r="3.5" stroke="currentColor" strokeWidth="1.5" />
      <path
        d="M10 1.75v1.5M10 16.75v1.5M1.75 10h1.5M16.75 10h1.5M4.17 4.17l1.06 1.06M14.77 14.77l1.06 1.06M15.83 4.17l-1.06 1.06M5.23 14.77l-1.06 1.06"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

function MoonIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={className} fill="none">
      <path
        d="M16.25 12.4A6.9 6.9 0 0 1 7.6 3.75a6.9 6.9 0 1 0 8.65 8.65Z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}

const ICONS = {
  system: SystemIcon,
  dark: MoonIcon,
  light: SunIcon,
} as const;

export function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>("system");
  const [mounted, setMounted] = useState(false);
  const groupRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    const initial: ThemeMode = isThemeMode(stored) ? stored : "system";
    setMode(initial);
    applyTheme(initial);
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;

    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => {
      if (mode === "system") applyTheme("system");
    };

    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, [mode, mounted]);

  function choose(next: ThemeMode) {
    setMode(next);
    localStorage.setItem(STORAGE_KEY, next);
    applyTheme(next);
  }

  function onKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;

    event.preventDefault();
    const current = MODES.findIndex((entry) => entry.mode === mode);
    const offset = event.key === "ArrowRight" ? 1 : -1;
    const next = MODES[(current + offset + MODES.length) % MODES.length];
    choose(next.mode);
    groupRef.current
      ?.querySelector<HTMLButtonElement>(`[data-mode="${next.mode}"]`)
      ?.focus();
  }

  return (
    <div
      ref={groupRef}
      role="radiogroup"
      aria-label="Color theme"
      onKeyDown={onKeyDown}
      className="flex items-center gap-0.5 rounded-md border border-line bg-surface p-0.5"
    >
      {MODES.map((entry) => {
        const Icon = ICONS[entry.mode];
        const selected = mounted && mode === entry.mode;

        return (
          <button
            key={entry.mode}
            type="button"
            role="radio"
            aria-checked={selected}
            aria-label={entry.label}
            title={entry.label}
            data-mode={entry.mode}
            tabIndex={selected ? 0 : -1}
            onClick={() => choose(entry.mode)}
            className={`flex h-7 w-7 items-center justify-center rounded-[5px] outline-none transition-colors duration-150 focus-visible:ring-2 focus-visible:ring-accent/70 ${
              selected
                ? "bg-accent-soft text-accent"
                : "text-muted hover:bg-surface-2 hover:text-fg"
            }`}
          >
            <Icon className="h-4 w-4" />
          </button>
        );
      })}
    </div>
  );
}
