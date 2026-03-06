import { readFile, writeFile } from "ags/file";
import { notify } from "./notification";
import { exec } from "ags/process";

export function readJSONFile<T = any>(
  filePath: string,
  fallback: T = {} as T,
): T {
  try {
    const data = readFile(filePath);
    if (data == "" || !data.trim()) return fallback;
    return JSON.parse(data) as T;
  } catch (e) {
    return fallback;
  }
}

export function readJson(string: string) {
  try {
    // Validate input
    if (typeof string !== "string") {
      throw new TypeError("Input must be a string");
    }

    // Trim whitespace
    const trimmed = string.trim();

    if (trimmed === "") {
      throw new Error("Input string is empty");
    }

    return JSON.parse(trimmed);
  } catch (e) {
    // Provide more specific error messages
    let errorMessage = "Failed to parse JSON";

    if (e instanceof SyntaxError) {
      errorMessage = `Invalid JSON syntax: ${e.message}`;
    } else if (e instanceof TypeError) {
      errorMessage = e.message;
    } else if (e instanceof Error) {
      errorMessage = e.message;
    }

    notify({
      summary: "JSON Parse Error",
      body: errorMessage,
    });

    return null; // Return actual null instead of string "null"
  }
}
export function writeJSONFile(filePath: string, data: any) {
  const parentDir = filePath.split("/").slice(0, -1).join("/");
  const temporaryPath = `${filePath}.tmp`;

  try {
    exec(`mkdir -p "${parentDir}"`);
    writeFile(temporaryPath, JSON.stringify(data, null, 4));
    exec(`mv "${temporaryPath}" "${filePath}"`);
  } catch (e) {
    notify({ summary: "Error", body: String(e) });
  }
}
