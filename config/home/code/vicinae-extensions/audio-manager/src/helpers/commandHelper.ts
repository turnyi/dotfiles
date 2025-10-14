import { exec } from "child_process";
import { promisify } from "util";

const execRaw = promisify(exec);

export const execAsync = (command: string, options?: { timeout?: number }) => {
  return execRaw(command, {
    timeout: options?.timeout || 10000,
    ...options,
  });
};

export const parseTabSeparatedOutput = (output: string): string[][] => {
  return output
    .split("\n")
    .filter(Boolean)
    .map((line) => line.split(":"));
};

export const createSet = (output: string): Set<string> => {
  return new Set(output.split("\n").filter(Boolean));
};

export const parseKeyValueOutput = (output: string): Record<string, string> => {
  const result: Record<string, string> = {};
  output.split("\n").forEach((line) => {
    const [key, ...valueParts] = line.split(":");
    if (key && valueParts.length > 0) {
      result[key.trim()] = valueParts.join(":").trim();
    }
  });
  return result;
};
