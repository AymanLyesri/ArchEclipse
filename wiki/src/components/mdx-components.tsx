import Link from "next/link";
import { Callout } from "@/components/callout";
import { CodeBlock } from "@/components/code-block";
import { withBasePath } from "@/lib/site";

function MdxLink({
  href = "",
  children,
  ...props
}: React.ComponentPropsWithoutRef<"a">) {
  const isInternal = href.startsWith("/");
  const isHash = href.startsWith("#");

  if (isInternal) {
    return <Link href={href}>{children}</Link>;
  }

  if (isHash) {
    return (
      <a href={href} {...props}>
        {children}
      </a>
    );
  }

  return (
    <a href={href} target="_blank" rel="noreferrer" {...props}>
      {children}
    </a>
  );
}

function MdxImage({
  src = "",
  alt = "",
  ...props
}: Omit<React.ComponentPropsWithoutRef<"img">, "src"> & { src?: string }) {
  const resolved =
    src.startsWith("/") && !src.startsWith("//") ? withBasePath(src) : src;

  return (
    // MDX images are authored at fixed sizes; a plain img keeps the static
    // export simple and avoids a Next image loader on GitHub Pages.
    <img
      src={resolved}
      alt={alt}
      loading="lazy"
      decoding="async"
      {...props}
    />
  );
}

function MdxTable({ children, ...props }: React.ComponentPropsWithoutRef<"table">) {
  return (
    <div className="table-wrap">
      <table {...props}>{children}</table>
    </div>
  );
}

export const mdxComponents = {
  a: MdxLink,
  img: MdxImage,
  pre: CodeBlock,
  table: MdxTable,
  Callout,
};
