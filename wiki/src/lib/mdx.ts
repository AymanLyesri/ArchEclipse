import type { PluggableList } from "unified";
import rehypeShiki from "@shikijs/rehype";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";

const languages = [
  "bash",
  "shell",
  "json",
  "jsonc",
  "yaml",
  "javascript",
  "jsx",
  "typescript",
  "tsx",
  "qml",
  "cpp",
  "c",
  "python",
  "lua",
  "ini",
  "toml",
  "css",
  "html",
  "markdown",
  "diff",
  "text",
  "glsl",
];

const remarkPlugins: PluggableList = [remarkGfm];

const rehypePlugins: PluggableList = [
  rehypeSlug,
  [
    rehypeAutolinkHeadings,
    {
      behavior: "append",
      properties: {
        className: ["anchor"],
        ariaLabel: "Link to this section",
        tabIndex: -1,
      },
      content: { type: "text", value: "#" },
    },
  ],
  [
    rehypeShiki,
    {
      themes: {
        light: "vitesse-light",
        dark: "vitesse-dark",
      },
      defaultColor: false,
      defaultLanguage: "text",
      fallbackLanguage: "text",
      langs: languages,
      transformers: [
        {
          pre(node: { properties: Record<string, unknown> }) {
            const options = (
              this as unknown as { options?: { lang?: string } }
            ).options;
            if (options?.lang) {
              node.properties["data-language"] = options.lang;
            }
          },
        },
      ],
    },
  ],
];

export const mdxOptions = {
  remarkPlugins,
  rehypePlugins,
};
