import { readFile, writeFile } from "ags/file";
import { notify } from "./notification";
import { exec } from "ags/process";

export function readJSONFile(filePath: string): any {
  if (readFile(filePath) == "") return {};
  try {
    const data = readFile(filePath);
    return data.trim() ? JSON.parse(data) : {};
  } catch (e) {
    notify({ summary: "Error", body: String(e) });
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
  if (readFile(filePath) == "")
    exec(`mkdir -p ${filePath.split("/").slice(0, -1).join("/")}`);
  try {
    writeFile(filePath, JSON.stringify(data, null, 4));
  } catch (e) {
    notify({ summary: "Error", body: String(e) });
  }
}
