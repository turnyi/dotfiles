import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  showToast,
  Toast,
} from "@vicinae/api";
import React, { useCallback, useEffect, useState } from "react";
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
  seq: number;
  ts: number;
  app: string;
  icon: string;
  summary: string;
  body: string;
  urgency: number;
};

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

function relativeTime(ts: number): string {
  const seconds = Math.max(0, Math.floor(Date.now() / 1000 - ts));
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function urgencyColor(urgency: number): Color {
  if (urgency >= 2) return Color.Red;
  if (urgency === 0) return Color.SecondaryText;
  return Color.Blue;
}

export default function Command() {
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const raw = await fs.readFile(STORE, "utf8");
      setEntries(parseStore(raw));
      setError(null);
    } catch (e: unknown) {
      const code = (e as NodeJS.ErrnoException)?.code;
      if (code === "ENOENT") {
        setEntries([]);
        setError(null);
        return;
      }
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    load();
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
    await showToast({
      style: Toast.Style.Success,
      title: "History cleared",
    });
  }, [load]);

  if (error) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Warning}
          title="Could not read the notification store"
          description={error}
        />
      </List>
    );
  }

  const isLoading = entries === null;
  const items = entries ?? [];

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search notifications">
      {items.length === 0 && !isLoading ? (
        <List.EmptyView
          icon={Icon.Bell}
          title="No notifications recorded yet"
          description="The recorder stores notifications as they arrive. Anything shown before it started is not here."
        />
      ) : (
        items.map((entry, index) => (
          <List.Item
            key={`${entry.ts}-${index}`}
            icon={{ source: Icon.Bell, tintColor: urgencyColor(entry.urgency) }}
            title={entry.summary || "(no summary)"}
            subtitle={entry.body}
            keywords={[entry.app]}
            accessories={[{ text: entry.app }, { text: relativeTime(entry.ts) }]}
            actions={
              <ActionPanel>
                <Action.CopyToClipboard
                  title="Copy Body"
                  content={entry.body}
                />
                <Action.CopyToClipboard
                  title="Copy Summary"
                  content={entry.summary}
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
        ))
      )}
    </List>
  );
}
