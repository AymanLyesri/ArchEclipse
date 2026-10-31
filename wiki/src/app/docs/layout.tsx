import { DocsSidebar } from "@/components/docs-sidebar";
import { getNavGroups } from "@/lib/docs";

export default function DocsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const groups = getNavGroups();

  return (
    <div className="mx-auto w-full max-w-[1440px]">
      <div className="lg:grid lg:grid-cols-[258px_minmax(0,1fr)]">
        <DocsSidebar groups={groups} />
        <div className="min-w-0">{children}</div>
      </div>
    </div>
  );
}
