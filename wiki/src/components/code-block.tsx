"use client";

import { useRef, useState } from "react";

type CodeBlockProps = React.ComponentPropsWithoutRef<"pre"> & {
  "data-language"?: string;
};

const LANGUAGE_LABELS: Record<string, string> = {
  bash: "bash",
  shell: "shell",
  sh: "shell",
  zsh: "zsh",
  json: "json",
  jsonc: "jsonc",
  yaml: "yaml",
  yml: "yaml",
  js: "javascript",
  javascript: "javascript",
  ts: "typescript",
  typescript: "typescript",
  tsx: "tsx",
  jsx: "jsx",
  qml: "qml",
  cpp: "c++",
  c: "c",
  python: "python",
  py: "python",
  lua: "lua",
  ini: "ini",
  toml: "toml",
  css: "css",
  html: "html",
  markdown: "markdown",
  md: "markdown",
  diff: "diff",
  text: "text",
  plaintext: "text",
  glsl: "glsl",
  conf: "conf",
};

export function CodeBlock({
  children,
  className,
  "data-language": language,
  ...props
}: CodeBlockProps) {
  const preRef = useRef<HTMLPreElement>(null);
  const [state, setState] = useState<"idle" | "copied" | "failed">("idle");
  const label = LANGUAGE_LABELS[language ?? ""] ?? language ?? "text";

  async function copy() {
    const text = preRef.current?.querySelector("code")?.textContent ?? "";
    try {
      await navigator.clipboard.writeText(text);
      setState("copied");
    } catch {
      setState("failed");
    }
    window.setTimeout(() => setState("idle"), 1600);
  }

  return (
    <div className="code-block">
      <div className="code-block-head">
        <span className="code-block-lang">{label}</span>
        <button
          type="button"
          onClick={copy}
          data-copied={state === "copied"}
          aria-label={
            state === "copied"
              ? "Copied to clipboard"
              : state === "failed"
                ? "Copy failed"
                : "Copy code to clipboard"
          }
          className="code-block-copy"
        >
          {state === "copied" ? "Copied" : state === "failed" ? "Failed" : "Copy"}
        </button>
      </div>
      <pre ref={preRef} className={className} {...props}>
        {children}
      </pre>
    </div>
  );
}
