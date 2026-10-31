import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import GithubSlugger from "github-slugger";
import { toString } from "mdast-util-to-string";
import remarkMdx from "remark-mdx";
import remarkParse from "remark-parse";
import { unified } from "unified";
import { visit } from "unist-util-visit";

const CONTENT_DIR = path.join(process.cwd(), "content");

export type TocItem = {
  id: string;
  text: string;
  depth: 2 | 3;
};

export type DocFrontmatter = {
  title: string;
  description?: string;
  group?: string;
  groupOrder?: number;
  order?: number;
};

export type Doc = {
  slug: string[];
  href: string;
  title: string;
  description: string;
  group: string;
  groupOrder: number;
  order: number;
  content: string;
  toc: TocItem[];
  file: string;
};

export type NavItem = Omit<
  Doc,
  "content" | "toc" | "file" | "groupOrder" | "order"
>;

export type NavGroup = {
  title: string;
  items: NavItem[];
};

type FrontmatterInput = Partial<Record<keyof DocFrontmatter, unknown>>;

function parseFrontmatter(data: FrontmatterInput, file: string): DocFrontmatter {
  const fallbackTitle = path
    .basename(file, ".mdx")
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());

  return {
    title:
      typeof data.title === "string" && data.title.trim()
        ? data.title.trim()
        : fallbackTitle,
    description:
      typeof data.description === "string" ? data.description.trim() : "",
    group: typeof data.group === "string" ? data.group.trim() : undefined,
    groupOrder: toNumber(data.groupOrder),
    order: toNumber(data.order),
  };
}

function toNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return undefined;
}

function walk(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];

  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((entry) => {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) return walk(fullPath);
      if (entry.isFile() && entry.name.endsWith(".mdx")) return [fullPath];
      return [];
    });
}

/** Build a route slug from a content file: index.mdx maps to its folder. */
function toSlug(relativePath: string): string[] {
  const withoutExtension = relativePath.replace(/\\/g, "/").replace(/\.mdx$/, "");
  const parts = withoutExtension.split("/");
  if (parts[parts.length - 1] === "index") parts.pop();
  return parts;
}

function slugToHref(slug: string[]): string {
  return `/docs${slug.length ? `/${slug.join("/")}` : ""}`;
}

function titleCase(value: string): string {
  return value
    .split(/[-\s]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

export function extractToc(content: string): TocItem[] {
  const tree = unified().use(remarkParse).use(remarkMdx).parse(content);
  const slugger = new GithubSlugger();
  const headings: TocItem[] = [];

  visit(tree, "heading", (node) => {
    const depth = node.depth;
    if (depth !== 2 && depth !== 3) return;

    const text = toString(node).trim();
    if (!text) return;

    headings.push({
      id: slugger.slug(text),
      text,
      depth,
    });
  });

  return headings;
}

function readDoc(file: string): Doc {
  const relativePath = path.relative(CONTENT_DIR, file);
  const raw = fs.readFileSync(file, "utf8");
  const { data, content } = matter(raw);
  const frontmatter = parseFrontmatter(data as FrontmatterInput, file);
  const slug = toSlug(relativePath);
  const folder = slug[0] ? titleCase(slug[0]) : "";

  return {
    slug,
    href: slugToHref(slug),
    title: frontmatter.title,
    description: frontmatter.description ?? "",
    group: frontmatter.group ?? folder ?? "Documentation",
    groupOrder: frontmatter.groupOrder ?? 99,
    order: frontmatter.order ?? 999,
    content,
    toc: extractToc(content),
    file: relativePath,
  };
}

/** All documentation pages, sorted for navigation. */
export function getDocs(): Doc[] {
  return walk(CONTENT_DIR)
    .map(readDoc)
    .sort((a, b) => {
      if (a.groupOrder !== b.groupOrder) return a.groupOrder - b.groupOrder;
      if (a.group !== b.group) return a.group.localeCompare(b.group);
      if (a.order !== b.order) return a.order - b.order;
      return a.title.localeCompare(b.title);
    });
}

export function getDocBySlug(slug: string[]): Doc | undefined {
  const normalized = slug.join("/");
  return getDocs().find((doc) => doc.slug.join("/") === normalized);
}

export function getNavGroups(docs = getDocs()): NavGroup[] {
  const groups = new Map<string, Doc[]>();

  for (const doc of docs) {
    const list = groups.get(doc.group) ?? [];
    list.push(doc);
    groups.set(doc.group, list);
  }

  return [...groups.entries()]
    .sort(([, a], [, b]) => {
      const orderA = Math.min(...a.map((doc) => doc.groupOrder));
      const orderB = Math.min(...b.map((doc) => doc.groupOrder));
      return orderA - orderB;
    })
    .map(([title, items]) => ({
      title,
      items: items.map(({ content, toc, file, groupOrder, order, ...item }) => item),
    }));
}

export function getPrevNext(slug: string[]): {
  previous: NavItem | null;
  next: NavItem | null;
} {
  const flattened = getNavGroups().flatMap((group) => group.items);
  const index = flattened.findIndex(
    (doc) => doc.slug.join("/") === slug.join("/"),
  );

  if (index === -1) return { previous: null, next: null };

  return {
    previous: index > 0 ? flattened[index - 1] : null,
    next: index < flattened.length - 1 ? flattened[index + 1] : null,
  };
}

export function getStaticDocParams(): { slug: string[] }[] {
  return getDocs().map((doc) => ({ slug: doc.slug }));
}
