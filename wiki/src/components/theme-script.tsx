const script = `
(function () {
  try {
    var stored = localStorage.getItem("archeclipse-theme");
    var mode = stored === "dark" || stored === "light" || stored === "system" ? stored : "system";
    var dark = mode === "dark" || (mode === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    var root = document.documentElement;
    root.classList.toggle("dark", dark);
    root.dataset.theme = dark ? "dark" : "light";
    root.dataset.themeMode = mode;
    root.style.colorScheme = dark ? "dark" : "light";
  } catch (error) {}
})();
`;

export function ThemeScript() {
  return (
    <script
      dangerouslySetInnerHTML={{ __html: script }}
      suppressHydrationWarning
    />
  );
}
