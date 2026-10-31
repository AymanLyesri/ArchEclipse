type CalloutType = "note" | "tip" | "warning" | "danger";

const DEFAULT_TITLES: Record<CalloutType, string> = {
  note: "Note",
  tip: "Tip",
  warning: "Warning",
  danger: "Caution",
};

const ICONS: Record<CalloutType, React.ReactNode> = {
  note: (
    <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
      <circle cx="8" cy="8" r="6.25" stroke="currentColor" strokeWidth="1.3" />
      <path d="M8 7.2v3.4" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="8" cy="4.9" r="0.8" fill="currentColor" />
    </svg>
  ),
  tip: (
    <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
      <path
        d="M5.2 9.6a4 4 0 1 1 5.6 0c-.6.5-.9 1.1-.9 1.8H6.1c0-.7-.3-1.3-.9-1.8Z"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinejoin="round"
      />
      <path d="M6.3 13.3h3.4" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  warning: (
    <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
      <path
        d="M8 1.9 14.6 13H1.4L8 1.9Z"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinejoin="round"
      />
      <path d="M8 6v3.2" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="8" cy="11.2" r="0.8" fill="currentColor" />
    </svg>
  ),
  danger: (
    <svg viewBox="0 0 16 16" aria-hidden="true" className="h-3.5 w-3.5" fill="none">
      <circle cx="8" cy="8" r="6.25" stroke="currentColor" strokeWidth="1.3" />
      <path d="m5.9 5.9 4.2 4.2M10.1 5.9l-4.2 4.2" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  ),
};

export function Callout({
  type = "note",
  title,
  children,
}: {
  type?: CalloutType;
  title?: string;
  children: React.ReactNode;
}) {
  const kind = type in DEFAULT_TITLES ? type : "note";

  return (
    <aside className={`callout callout-${kind}`}>
      <p className="callout-title">
        {ICONS[kind]}
        {title ?? DEFAULT_TITLES[kind]}
      </p>
      <div className="callout-body">{children}</div>
    </aside>
  );
}
