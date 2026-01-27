/**
 *
 * @param kb number in kilobytes
 * @returns formatted string with appropriate unit
 */
export function formatKiloBytes(kb: number): string {
  if (kb === undefined || kb === null || isNaN(kb)) {
    return "0.0 KB";
  }
  const units = ["KB", "MB", "GB", "TB"];
  let idx = 0;
  let val = kb;
  while (val >= 1024 && idx < units.length - 1) {
    val /= 1024;
    idx++;
  }
  return `${val.toFixed(2)} ${units[idx]}`;
}
