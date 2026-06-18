import Apps from "gi://AstalApps";
import Gio from "gi://Gio";
import GLib from "gi://GLib";
import { LauncherApp } from "../../../interfaces/app.interface";

const apps = new Apps.Apps();

// Helper to convert Gio.AppInfo to a format compatible with launchAndRecord
type AppWithLaunch = {
  name: string;
  launch: () => boolean;
};

function appInfoToCompatibleApp(appInfo: Gio.AppInfo): AppWithLaunch {
  return {
    name: appInfo.get_name() || "",
    launch: () => {
      try {
        // Gio.AppInfo.launch() requires files (GList) and context parameters
        // Pass empty array for files and null for context
        return appInfo.launch([], null);
      } catch (e) {
        console.error("Failed to launch app:", e);
        return false;
      }
    },
  };
}

function fuzzyMatchAppInfo(appInfo: Gio.AppInfo, query: string): boolean {
  const name = appInfo.get_name() || "";
  const description = appInfo.get_description() || "";
  const id = appInfo.get_id() || "";

  const lowerQuery = query.toLowerCase();
  const lowerName = name.toLowerCase();
  const lowerDescription = description.toLowerCase();
  const lowerId = id.toLowerCase();

  return (
    lowerName.includes(lowerQuery) ||
    lowerDescription.includes(lowerQuery) ||
    lowerId.includes(lowerQuery)
  );
}

// Group applications by their desktop file location
function getAppSourceGroup(appInfo: Gio.AppInfo): string {
  const filename = appInfo.get_filename() || "";
  const homeDir = GLib.get_home_dir();

  // Flatpak user applications
  if (
    filename.includes(
      `${homeDir}/.local/share/flatpak/exports/share/applications/`,
    )
  ) {
    return "Flatpak User Applications";
  }

  // Flatpak system applications
  if (filename.includes("/var/lib/flatpak/exports/share/applications/")) {
    return "Flatpak System Applications";
  }

  // User applications
  if (filename.includes(`${homeDir}/.local/share/applications/`)) {
    return "User Applications";
  }

  // System applications
  if (
    filename.includes("/usr/share/applications/") ||
    filename.includes("/usr/local/share/applications/")
  ) {
    return "System Applications";
  }

  // Default group
  return "Other Applications";
}

// Create a header entry for a group
function createHeaderEntry(groupName: string): LauncherApp {
  return {
    app_name: groupName,
    app_type: "header",
    app_icon: "",
    app_launch: () => {},
  };
}

export const parseAppsQuery = (value: string): string | null => {
  const normalized = value.trimStart();
  // Reacts to "apps" or "Apps" (exact match) or "apps " with space
  const appsExactMatch = /^apps$/i.test(normalized);
  const appsWithSpaceMatch = /^apps\s+/i.test(normalized);

  if (appsExactMatch) {
    // If exactly "apps" or "Apps" - return empty query to show all apps
    return "";
  }

  if (appsWithSpaceMatch) {
    // If "apps " with space - return the rest as search query
    return normalized.replace(/^apps\s+/i, "").toLowerCase();
  }

  return null;
};

export const getAppsResults = (
  query: string,
  launchAndRecord: (application: Apps.Application) => void,
): LauncherApp[] => {
  // Use Gio.AppInfo to get ALL applications including flatpak ones
  const allApps = Gio.AppInfo.get_all();

  // If nothing is entered after "apps", we return absolutely ALL installed apps.
  // If there is text, we filter by it using our own fuzzy matching.
  const candidates =
    query === ""
      ? allApps
      : allApps.filter((appInfo) => fuzzyMatchAppInfo(appInfo, query));

  // Group applications by their source
  const groups: Map<string, Gio.AppInfo[]> = new Map();

  candidates.forEach((appInfo: Gio.AppInfo) => {
    const groupName = getAppSourceGroup(appInfo);
    if (!groups.has(groupName)) {
      groups.set(groupName, []);
    }
    groups.get(groupName)!.push(appInfo);
  });

  // Build the result array with headers
  const results: LauncherApp[] = [];

  // Sort groups in a specific order
  const groupOrder = [
    "User Applications",
    "Flatpak User Applications",
    "System Applications",
    "Flatpak System Applications",
    "Other Applications",
  ];

  for (const groupName of groupOrder) {
    const groupApps = groups.get(groupName);
    if (groupApps && groupApps.length > 0) {
      // Add header
      results.push(createHeaderEntry(groupName));

      // Add applications
      groupApps.forEach((appInfo: Gio.AppInfo) => {
        const compatibleApp = appInfoToCompatibleApp(appInfo);
        results.push({
          app_name: appInfo.get_name() || "",
          app_icon: appInfo.get_icon()?.to_string() || "",
          app_description: appInfo.get_description() || "Installed Application",
          app_type: "app",
          app_launch: () =>
            launchAndRecord(compatibleApp as unknown as Apps.Application),
        });
      });
    }
  }

  return results;
};
