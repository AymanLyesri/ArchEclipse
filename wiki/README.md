# ArchEclipse Documentation

A static documentation site for [ArchEclipse](https://github.com/AymanLyesri/ArchEclipse), built with Next.js App Router, MDX, Tailwind CSS, Shiki and Pagefind.

The site is fully static: no server, no database and no runtime API. Documentation pages are read from `content/` at build time and exported to `out/`.

## Stack

| Concern | Implementation |
| --- | --- |
| Framework | Next.js (App Router, static export) |
| Content | MDX files in `content/` |
| Styling | Tailwind CSS v4 plus a small design-token layer in `src/app/globals.css` |
| Syntax highlighting | Shiki through `@shikijs/rehype` (dual light/dark themes) |
| Search | Pagefind, indexed from the exported HTML after `next build` |
| Typography | Inter Variable and JetBrains Mono Variable, self-hosted via Fontsource |
| Theme | System / dark / light, persisted in `localStorage`, applied before paint |

## Requirements

- Node.js 22 (Next.js 16 requires Node.js 20.9 or newer)
- npm

## Development

```bash
npm install
npm run dev
```

Open <http://localhost:3000>. The development server renders all pages, navigation, tables of contents and code highlighting.

Search is the one feature that needs the production build: Pagefind indexes the exported HTML, so `npm run dev` shows a "search index is not available" message until you build the site.

## Production build and preview

```bash
npm run build
npx serve out
```

`npm run build` runs `next build` and then `pagefind --site out`, which writes the search index into `out/pagefind`. Use any static file server for `out/`; client-side navigation falls back to full page loads on a plain server, which is expected for a static export.

Run the type check on its own with:

```bash
npm run lint
```

## Project structure

```
content/                     MDX documentation
  introduction.mdx
  getting-started/
  configuration/
  support/
public/images/               Screenshots referenced by MDX
src/app/
  layout.tsx                 Root shell, metadata, theme script
  page.tsx                   Landing page
  globals.css                Design tokens, prose, code blocks, search palette
  docs/layout.tsx            Sidebar shell for documentation
  docs/page.tsx              Documentation index
  docs/[...slug]/page.tsx    Static MDX page renderer
src/components/              Reusable UI (header, sidebar, TOC, search, code block)
src/lib/
  docs.ts                    Content discovery, navigation, TOC and prev/next
  mdx.ts                     MDX pipeline (GFM, heading ids/anchors, Shiki)
  site.ts                    Site metadata and base-path helpers
```

The separation is deliberate: `src/lib/docs.ts` is the only place that knows how content maps to routes and navigation, and components receive typed props from it.

## Adding a documentation page

Create an `.mdx` file anywhere under `content/`. Routes are derived from the file path:

- `content/configuration/bar.mdx` → `/docs/configuration/bar`
- `content/support/faq.mdx` → `/docs/support/faq`
- `content/getting-started/index.mdx` → `/docs/getting-started`

Frontmatter is required for a good title and ordering, but every field has a fallback:

```yaml
---
title: Bar
description: How the bar is structured and how to control it.
group: Configuration
groupOrder: 2
order: 4
---
```

| Field | Purpose |
| --- | --- |
| `title` | Page title, sidebar label and search title. Falls back to a title-cased filename. |
| `description` | Page subtitle, documentation index card and meta description. |
| `group` | Sidebar section. Falls back to the title-cased first folder. |
| `groupOrder` | Section order in the sidebar. Lower comes first (default `99`). |
| `order` | Page order inside its section (default `999`). |

No registry, route file or search configuration needs editing: the sidebar, breadcrumbs, previous/next links, table of contents, static params and Pagefind index are all generated from the files.

### MDX components

`Callout` is available without importing it:

```mdx
<Callout type="warning" title="Local changes are discarded">
  The updater resets tracked files.
</Callout>
```

Types are `note`, `tip`, `warning` and `danger`. Standard Markdown tables, lists, images and fenced code blocks work. Supported Shiki languages include Bash, Shell, JSON, YAML, JavaScript, TypeScript, JSX/TSX, QML, C, C++, Python, Lua, TOML, INI, CSS, HTML, Markdown, diff and GLSL.

Images in `public/` are referenced with site-absolute paths such as `/images/launcher.webp`; the MDX image component prefixes the deployment base path automatically.

## Theme handling

`src/components/theme-script.tsx` is an inline script in `<head>` that reads `archeclipse-theme` from `localStorage` and applies the `dark` class before the body paints. This prevents a flash of the wrong theme. `ThemeToggle` keeps the selection in sync, listens for OS changes while in System mode, and stores manual selections.

## Deployment to GitHub Pages

The site is configured for static export in `next.config.ts`:

- `output: "export"`
- `trailingSlash: true`
- `images.unoptimized: true`
- optional `basePath` from `NEXT_PUBLIC_BASE_PATH`

For a project site at `https://<user>.github.io/ArchEclipse/`, build with the repository name as the base path:

```bash
NEXT_PUBLIC_BASE_PATH=/ArchEclipse npm run build
```

Leave `NEXT_PUBLIC_BASE_PATH` unset for local development or a user/root Pages site. The same value is used by navigation, images and the Pagefind runtime.

`.github/workflows/deploy.yml` builds and publishes `out/` through GitHub Actions. Enable **Settings → Pages → Build and deployment → GitHub Actions** before the first run. The workflow detects the repository name and sets the base path automatically, skipping it for `<user>.github.io` repositories.

If this `wiki/` directory lives inside a larger repository, move the workflow to the repository root, set `defaults.run.working-directory: wiki`, point the npm cache at `wiki/package-lock.json`, and upload `wiki/out`.

## Documentation accuracy

The guides document the repository as it exists on `master`: real paths, commands, defaults and trade-offs. Where a behavior could not be verified from the source, the page says **TODO** instead of guessing. Current TODOs cover measured install sizes, a tested distribution matrix, WallEclipse's text output format, a Quickshell-free setup, greeter font configuration, and the counter endpoint's stored data.

## License

Documentation content describes ArchEclipse, which is licensed under GPL-3.0. See the [project license](https://github.com/AymanLyesri/ArchEclipse/blob/master/LICENSE).
