import { Application, Color, Icon, ImageLike } from "@vicinae/api";
import { exec } from "child_process";
import fs from "fs/promises";
import os from "os";
import path from "path";
import util from "util";

export const execp = util.promisify(exec);

const STATE_DIR = path.join(
  process.env.XDG_STATE_HOME ?? path.join(os.homedir(), ".local/state"),
  "notification-history",
);

export const HISTORY_STORE = path.join(STATE_DIR, "history.jsonl");
export const PENDING_STORE = path.join(STATE_DIR, "pending.json");

export type Entry = {
  id?: number;
  ts: number;
  app: string;
  desktopEntry?: string;
  icon: string;
  summary: string;
  body: string;
  urgency: number;
};

export type Identity = { name: string; icon: ImageLike };

function isEntry(value: unknown): value is Entry {
  return typeof (value as Entry)?.summary === "string";
}

export function parseHistory(raw: string): Entry[] {
  const entries: Entry[] = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      const parsed = JSON.parse(line);
      if (isEntry(parsed)) entries.push(parsed);
    } catch {
      continue;
    }
  }
  return entries.reverse();
}

export async function readHistory(): Promise<Entry[]> {
  try {
    return parseHistory(await fs.readFile(HISTORY_STORE, "utf8"));
  } catch (e: unknown) {
    if ((e as NodeJS.ErrnoException)?.code === "ENOENT") return [];
    throw e;
  }
}

export async function removeFromHistory(target: Entry) {
  const raw = await fs.readFile(HISTORY_STORE, "utf8");
  const kept = raw
    .split("\n")
    .filter((line) => {
      if (!line.trim()) return false;
      try {
        const parsed = JSON.parse(line) as Entry;
        return !(parsed.ts === target.ts && parsed.summary === target.summary);
      } catch {
        return true;
      }
    });
  await fs.writeFile(HISTORY_STORE, kept.map((l) => `${l}\n`).join(""), {
    mode: 0o600,
  });
}

export async function clearHistory() {
  await fs.writeFile(HISTORY_STORE, "", { mode: 0o600 });
}

// The recorder only knows what it saw close; swaync's own count is the
// authority on whether anything is still pending at all.
export async function readPending(): Promise<Entry[]> {
  const { stdout } = await execp("swaync-client --skip-wait --count").catch(
    () => ({ stdout: "" }),
  );
  if (stdout.trim() === "0") return [];
  try {
    const parsed = JSON.parse(await fs.readFile(PENDING_STORE, "utf8"));
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((e): e is Entry => isEntry(e) && typeof e.id === "number")
      .sort((a, b) => b.ts - a.ts);
  } catch {
    return [];
  }
}

export async function dismissNotification(id: number) {
  await execp(
    `busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications CloseNotification u ${id}`,
  );
}

export async function dismissAll() {
  await execp("swaync-client --close-all");
}

const ORIGIN_LINE = /^(https?:\/\/)?([a-z0-9-]+\.)+[a-z]{2,}(\/\S*)?$/i;

const BROWSERS = new Set([
  "google-chrome",
  "google-chrome-stable",
  "chromium",
  "brave-browser",
  "firefox",
  "microsoft-edge",
]);

function normalizeId(value: string): string {
  return value.trim().replace(/\.desktop$/i, "").toLowerCase();
}

function squash(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function firstWord(value: string): string {
  return value.trim().split(/\s+/)[0] ?? value;
}

function originOf(body: string): string | null {
  const first = body.split("\n")[0]?.trim() ?? "";
  if (!first || !ORIGIN_LINE.test(first)) return null;
  return first
    .replace(/^https?:\/\//i, "")
    .replace(/\/.*$/, "")
    .toLowerCase();
}

const PUBLIC_SUFFIX_HEAD = new Set(["co", "com", "net", "org", "gov", "edu", "ac"]);

// news.ycombinator.com -> Ycombinator, web.whatsapp.com -> Whatsapp: the
// registrable label, not whatever subdomain the notification happened to use.
function siteLabel(origin: string): string {
  const parts = origin.split(".").filter(Boolean);
  if (parts.length < 2) return origin;
  let index = parts.length - 2;
  if (index > 0 && PUBLIC_SUFFIX_HEAD.has(parts[index])) index -= 1;
  const label = parts[index];
  return label.charAt(0).toUpperCase() + label.slice(1);
}

function findApp(apps: Application[], predicate: (a: Application) => boolean) {
  return apps.find(predicate) ?? null;
}

function appIdentity(app: Application): Identity {
  return { name: app.name, icon: app.icon || Icon.AppWindow };
}

// A site notification arrives as the browser, so the origin in the body is the
// only thing that names the PWA or website that actually sent it.
export function identityOf(entry: Entry, apps: Application[]): Identity {
  const desktopEntry = normalizeId(entry.desktopEntry ?? "");
  const byEntry = desktopEntry
    ? findApp(apps, (a) => normalizeId(a.id) === desktopEntry)
    : null;
  const isBrowser = !desktopEntry || BROWSERS.has(desktopEntry);

  if (isBrowser) {
    const origin = originOf(entry.body);
    if (origin) {
      const label = siteLabel(origin);
      const key = squash(label);
      const matches = apps.filter(
        (a) => squash(a.name) === key || squash(firstWord(a.name)) === key,
      );
      const names = new Set(matches.map((a) => squash(a.name)));
      // One name matched by several entries is the same site installed under
      // more than one browser; several names means "google" style ambiguity,
      // where guessing an app is worse than showing the site plainly.
      if (matches.length && names.size === 1) {
        const prefix = desktopEntry.startsWith("firefox") ? "ffpwa" : "chrome-";
        const preferred =
          matches.find((a) => normalizeId(a.id).startsWith(prefix)) ?? matches[0];
        return appIdentity(preferred);
      }
      return { name: label, icon: Icon.Globe };
    }
  }

  if (byEntry) return appIdentity(byEntry);

  const byName = findApp(apps, (a) => squash(a.name) === squash(entry.app));
  if (byName) return appIdentity(byName);
  return { name: entry.app || "Unknown", icon: Icon.Bell };
}

// Chrome opens a web notification's body with the sending origin on its own
// line, which would otherwise be the whole preview for WhatsApp Web or Slack.
export function messageText(body: string): string {
  const lines = body.split("\n");
  let start = 0;
  while (start < lines.length) {
    const line = lines[start].trim();
    if (line === "" || ORIGIN_LINE.test(line)) {
      start += 1;
      continue;
    }
    break;
  }
  const stripped = lines.slice(start).join(" ").replace(/\s+/g, " ").trim();
  return stripped || body.replace(/\s+/g, " ").trim();
}

export function relativeTime(ts: number): string {
  const seconds = Math.max(0, Math.floor(Date.now() / 1000 - ts));
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export function urgentTag(urgency: number) {
  return urgency >= 2 ? [{ tag: { value: "urgent", color: Color.Red } }] : [];
}
