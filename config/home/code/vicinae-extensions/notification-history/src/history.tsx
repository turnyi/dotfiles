import {
  Action,
  ActionPanel,
  Application,
  Color,
  Icon,
  ImageLike,
  List,
  getApplications,
  showToast,
  Toast,
  useNavigation,
} from "@vicinae/api";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import { exec } from "child_process";
import fs from "fs/promises";
import os from "os";
import path from "path";
import util from "util";

const execp = util.promisify(exec);

const STORE = path.join(
  process.env.XDG_STATE_HOME ?? path.join(os.homedir(), ".local/state"),
  "notification-history",
  "history.jsonl",
);

type Entry = {
  ts: number;
  app: string;
  desktopEntry?: string;
  icon: string;
  summary: string;
  body: string;
  urgency: number;
};

type Thread = {
  key: string;
  app: string;
  icon: ImageLike;
  sender: string;
  entries: Entry[];
  latest: Entry;
};

type ViewMode = "threads" | "apps" | "all";

function parseStore(raw: string): Entry[] {
  const entries: Entry[] = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      const parsed = JSON.parse(line) as Entry;
      if (typeof parsed.summary === "string") entries.push(parsed);
    } catch {
      continue;
    }
  }
  return entries.reverse();
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

type Identity = { name: string; icon: ImageLike };

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
function identityOf(entry: Entry, apps: Application[]): Identity {
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

// Messaging apps put the person in the summary and the message in the body, so
// the summary is the closest thing to a sender the spec gives us.
function senderLabel(entry: Entry, identity: Identity): string {
  return entry.summary.trim() || identity.name;
}

// Chrome opens a web notification's body with the sending origin on its own
// line, which would otherwise be the whole preview for WhatsApp Web or Slack.
function messageText(body: string): string {
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

function relativeTime(ts: number): string {
  const seconds = Math.max(0, Math.floor(Date.now() / 1000 - ts));
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function urgentTag(urgency: number) {
  return urgency >= 2 ? [{ tag: { value: "urgent", color: Color.Red } }] : [];
}

function buildThreads(
  entries: Entry[],
  apps: Application[],
  byAppOnly: boolean,
): Thread[] {
  const map = new Map<string, Thread>();
  for (const entry of entries) {
    const identity = identityOf(entry, apps);
    const sender = byAppOnly ? identity.name : senderLabel(entry, identity);
    const key = `${identity.name}::${sender}`;
    const existing = map.get(key);
    if (existing) {
      existing.entries.push(entry);
    } else {
      map.set(key, {
        key,
        app: identity.name,
        icon: identity.icon,
        sender,
        entries: [entry],
        latest: entry,
      });
    }
  }
  return [...map.values()].sort((a, b) => b.latest.ts - a.latest.ts);
}

function EntryActions({
  entry,
  onClearPending,
  onClearHistory,
  onReload,
}: {
  entry: Entry;
  onClearPending: () => void;
  onClearHistory: () => void;
  onReload: () => void;
}) {
  return (
    <ActionPanel>
      <Action.CopyToClipboard
        title="Copy Message"
        content={messageText(entry.body)}
      />
      <Action.CopyToClipboard title="Copy Summary" content={entry.summary} />
      <Action
        title="Clear Pending Notifications"
        icon={Icon.Checkmark}
        onAction={onClearPending}
      />
      <Action
        title="Clear Recorded History"
        icon={Icon.Trash}
        style={Action.Style.Destructive}
        onAction={onClearHistory}
      />
      <Action title="Reload" icon={Icon.ArrowClockwise} onAction={onReload} />
    </ActionPanel>
  );
}

function ThreadView({
  thread,
  onClearPending,
  onClearHistory,
  onReload,
}: {
  thread: Thread;
  onClearPending: () => void;
  onClearHistory: () => void;
  onReload: () => void;
}) {
  return (
    <List
      navigationTitle={`${thread.sender} · ${thread.app}`}
      searchBarPlaceholder={`Search ${thread.entries.length} notifications`}
    >
      {thread.entries.map((entry, index) => (
        <List.Item
          key={`${entry.ts}-${index}`}
          icon={{ source: thread.icon, fallback: Icon.Bell }}
          title={messageText(entry.body) || entry.summary}
          accessories={[
            ...urgentTag(entry.urgency),
            { text: relativeTime(entry.ts) },
          ]}
          actions={
            <EntryActions
              entry={entry}
              onClearPending={onClearPending}
              onClearHistory={onClearHistory}
              onReload={onReload}
            />
          }
        />
      ))}
    </List>
  );
}

export default function Command() {
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [apps, setApps] = useState<Application[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [mode, setMode] = useState<ViewMode>("threads");
  const { push } = useNavigation();

  const load = useCallback(async () => {
    try {
      const raw = await fs.readFile(STORE, "utf8");
      setEntries(parseStore(raw));
      setError(null);
    } catch (e: unknown) {
      if ((e as NodeJS.ErrnoException)?.code === "ENOENT") {
        setEntries([]);
        setError(null);
        return;
      }
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    load();
    getApplications()
      .then(setApps)
      .catch(() => setApps([]));
  }, [load]);

  const clearPending = useCallback(async () => {
    await execp("swaync-client --close-all");
    await showToast({
      style: Toast.Style.Success,
      title: "Pending notifications cleared",
    });
  }, []);

  const clearHistory = useCallback(async () => {
    await fs.writeFile(STORE, "", { mode: 0o600 });
    await load();
    await showToast({ style: Toast.Style.Success, title: "History cleared" });
  }, [load]);

  const items = useMemo(() => entries ?? [], [entries]);
  const threads = useMemo(
    () => (mode === "all" ? [] : buildThreads(items, apps, mode === "apps")),
    [items, apps, mode],
  );

  const dropdown = (
    <List.Dropdown
      tooltip="Group notifications"
      storeValue
      value={mode}
      onChange={(next) => setMode(next as ViewMode)}
    >
      <List.Dropdown.Item title="By Sender" value="threads" />
      <List.Dropdown.Item title="By App" value="apps" />
      <List.Dropdown.Item title="All Notifications" value="all" />
    </List.Dropdown>
  );

  if (error) {
    return (
      <List searchBarAccessory={dropdown}>
        <List.EmptyView
          icon={Icon.Warning}
          title="Could not read the notification store"
          description={error}
        />
      </List>
    );
  }

  const isLoading = entries === null;

  if (!isLoading && items.length === 0) {
    return (
      <List searchBarAccessory={dropdown}>
        <List.EmptyView
          icon={Icon.Bell}
          title="No notifications recorded yet"
          description="The recorder stores notifications as they arrive. Anything shown before it started is not here."
        />
      </List>
    );
  }

  if (mode === "all") {
    return (
      <List
        isLoading={isLoading}
        searchBarPlaceholder="Search notifications"
        searchBarAccessory={dropdown}
      >
        {items.map((entry, index) => (
          <List.Item
            key={`${entry.ts}-${index}`}
            icon={{
              source: identityOf(entry, apps).icon,
              fallback: Icon.Bell,
            }}
            title={entry.summary || "(no summary)"}
            subtitle={messageText(entry.body)}
            keywords={[identityOf(entry, apps).name]}
            accessories={[
              ...urgentTag(entry.urgency),
              { text: identityOf(entry, apps).name },
              { text: relativeTime(entry.ts) },
            ]}
            actions={
              <EntryActions
                entry={entry}
                onClearPending={clearPending}
                onClearHistory={clearHistory}
                onReload={load}
              />
            }
          />
        ))}
      </List>
    );
  }

  const sections = new Map<string, Thread[]>();
  for (const thread of threads) {
    const bucket = sections.get(thread.app);
    if (bucket) bucket.push(thread);
    else sections.set(thread.app, [thread]);
  }

  const renderThread = (thread: Thread) => (
    <List.Item
      key={thread.key}
      icon={{ source: thread.icon, fallback: Icon.Bell }}
      title={thread.sender}
      subtitle={messageText(thread.latest.body)}
      keywords={[thread.app]}
      accessories={[
        ...urgentTag(thread.latest.urgency),
        { text: `${thread.entries.length}` },
        { text: relativeTime(thread.latest.ts) },
      ]}
      actions={
        <ActionPanel>
          <Action
            title="Open Thread"
            icon={Icon.ArrowRight}
            onAction={() =>
              push(
                <ThreadView
                  thread={thread}
                  onClearPending={clearPending}
                  onClearHistory={clearHistory}
                  onReload={load}
                />,
              )
            }
          />
          <Action.CopyToClipboard
            title="Copy Latest Message"
            content={messageText(thread.latest.body)}
          />
          <Action
            title="Clear Pending Notifications"
            icon={Icon.Checkmark}
            onAction={clearPending}
          />
          <Action
            title="Clear Recorded History"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={clearHistory}
          />
          <Action title="Reload" icon={Icon.ArrowClockwise} onAction={load} />
        </ActionPanel>
      }
    />
  );

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Search senders and apps"
      searchBarAccessory={dropdown}
    >
      {mode === "apps"
        ? threads.map(renderThread)
        : [...sections.entries()].map(([app, appThreads]) => (
            <List.Section
              key={app}
              title={app}
              subtitle={`${appThreads.length}`}
            >
              {appThreads.map(renderThread)}
            </List.Section>
          ))}
    </List>
  );
}
