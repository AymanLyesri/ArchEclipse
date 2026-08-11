import Apps from "gi://AstalApps";

const isSubsequence = (query: string, target: string): boolean => {
  let i = 0;
  for (const char of target) {
    if (char === query[i]) i++;
    if (i === query.length) return true;
  }
  return i === query.length;
};

/**
 * Rank apps by match quality first, launch history second. Tiers are
 * 200 apart while history boost + name-length penalty stay below 100,
 * so a frequently used app can rise within its tier but a metadata
 * match can never outrank a name match.
 */
export function rankApps(
  query: string,
  list: Apps.Application[],
  history: string[],
): Apps.Application[] {
  const q = query.toLowerCase();

  return list
    .map((app) => {
      const name = (app.name ?? "").toLowerCase();
      let score = 0;

      if (name === q) score = 1000;
      else if (name.startsWith(q)) score = 900;
      else if (name.split(/[\s\-_]+/).some((word) => word.startsWith(q)))
        score = 800;
      else if (name.includes(q)) score = 600;
      else if (isSubsequence(q, name)) score = 400;
      else {
        const meta =
          `${app.entry ?? ""} ${app.executable ?? ""} ${app.description ?? ""}`.toLowerCase();
        if (meta.includes(q)) score = 200;
      }

      if (score > 0) {
        const recency = history.indexOf(app.name);
        if (recency >= 0) score += Math.max(48 - recency * 8, 8);
        score -= Math.min(name.length, 40);
      }

      return { app, score };
    })
    .filter((entry) => entry.score > 0)
    .sort(
      (a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name),
    )
    .map((entry) => entry.app);
}
