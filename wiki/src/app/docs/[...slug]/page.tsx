import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { compileMDX } from "next-mdx-remote/rsc";
import { Breadcrumbs } from "@/components/breadcrumbs";
import { mdxComponents } from "@/components/mdx-components";
import { PrevNext } from "@/components/prev-next";
import {
  MobileTableOfContents,
  TableOfContents,
} from "@/components/table-of-contents";
import {
  getDocBySlug,
  getPrevNext,
  getStaticDocParams,
} from "@/lib/docs";
import { mdxOptions } from "@/lib/mdx";

export const dynamicParams = false;

export function generateStaticParams() {
  return getStaticDocParams();
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string[] }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const doc = getDocBySlug(slug);

  if (!doc) return {};

  return {
    title: doc.title,
    description: doc.description || undefined,
    openGraph: {
      title: doc.title,
      description: doc.description || undefined,
      type: "article",
    },
  };
}

export default async function DocPage({
  params,
}: {
  params: Promise<{ slug: string[] }>;
}) {
  const { slug } = await params;
  const doc = getDocBySlug(slug);

  if (!doc) notFound();

  const { content } = await compileMDX({
    source: doc.content,
    components: mdxComponents,
    options: { mdxOptions },
  });

  const { previous, next } = getPrevNext(doc.slug);

  return (
    <div className="px-5 py-8 sm:px-8 lg:px-10 lg:py-12">
      <div className="mx-auto grid max-w-[1120px] gap-12 xl:grid-cols-[minmax(0,760px)_210px] xl:justify-between">
        <div className="min-w-0">
          <Breadcrumbs group={doc.group} title={doc.title} />
          <MobileTableOfContents items={doc.toc} />

          <article data-pagefind-body>
            <header className="mb-8">
              <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-accent">
                {doc.group}
              </p>
              <h1 className="text-[2rem] leading-[1.2] font-semibold tracking-[-0.025em] text-fg sm:text-[2.25rem]">
                {doc.title}
              </h1>
              {doc.description ? (
                <p className="mt-3 max-w-[62ch] text-[15px] leading-relaxed text-muted">
                  {doc.description}
                </p>
              ) : null}
            </header>

            <div className="prose">{content}</div>
          </article>

          <PrevNext previous={previous} next={next} />
        </div>

        <TableOfContents items={doc.toc} />
      </div>
    </div>
  );
}
