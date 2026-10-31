"use client";

import { useState } from "react";

export function CommandSnippet({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      setCopied(false);
    }
  }

  return (
    <div className="flex items-center gap-2 rounded-lg border border-line bg-code px-3 py-2.5">
      <span aria-hidden="true" className="select-none font-mono text-[12px] text-accent">
        $
      </span>
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-[12px] text-fg/90">
        {command}
      </code>
      <button
        type="button"
        onClick={copy}
        aria-label={copied ? "Copied install command" : "Copy install command"}
        className="shrink-0 rounded border border-transparent px-2 py-1 font-mono text-[10.5px] text-muted outline-none transition-colors hover:border-line hover:bg-surface hover:text-fg focus-visible:ring-2 focus-visible:ring-accent/70"
      >
        {copied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}
