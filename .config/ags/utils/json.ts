import { readFile, writeFile } from "ags/file";
import { notify } from "./notification";
import { exec } from "ags/process";

export function readJSONFile(filePath: string): any {
  try {
    const data = readFile(filePath);
    if (data == "" || !data.trim()) return {};
    return JSON.parse(data);
  } catch (e) {
    // File doesn't exist or can't be read, return empty object
    return {};
  }
}

export function readJson(string: string) {
  try {
    return JSON.parse(string);
  } catch (e) {
    notify({ summary: "Error", body: String(e) });
    return "null";
  }
}

export function writeJSONFile(filePath: string, data: any) {
  // Ensure directory exists before writing
  exec(`mkdir -p ${filePath.split("/").slice(0, -1).join("/")}`);
  try {
    writeFile(filePath, JSON.stringify(data, null, 4));
  } catch (e) {
    notify({ summary: "Error", body: String(e) });
  }
}
