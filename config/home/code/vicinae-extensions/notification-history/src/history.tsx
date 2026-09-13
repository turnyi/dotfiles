import {
  Action,
  ActionPanel,
  Application,
  Icon,
  ImageLike,
  List,
  getApplications,
  showToast,
  Toast,
  useNavigation,
} from "@vicinae/api";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  Entry,
  Identity,
  clearHistory,
  identityOf,
  messageText,
  readHistory,
  relativeTime,
  removeFromHistory,
  urgentTag,
} from "./shared";

type Thread = {
  key: string;
  app: string;
  icon: ImageLike;
  sender: string;
  entries: Entry[];
  latest: Entry;
};

type ViewMode = "threads" | "apps" | "all";

// Messaging apps put the person in the summary and the message in the body, so
// the summary is the closest thing to a sender the spec gives us.
function senderLabel(entry: Entry, identity: Identity): string {
  return entry.summary.trim() || identity.name;
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

type Handlers = {
  onRemove: (entry: Entry) => void;
  onClearHistory: () => void;
  onReload: () => void;
};

function EntryActions({ entry, handlers }: { entry: Entry; handlers: Handlers }) {
  return (
    <ActionPanel>
      <Action.CopyToClipboard
        title="Copy Message"
        content={messageText(entry.body)}
      />
      <Action.CopyToClipboard title="Copy Summary" content={entry.summary} />
      <Action
        title="Remove from History"
        icon={Icon.XMarkCircle}
        shortcut={{ modifiers: ["ctrl"], key: "x" }}
        onAction={() => handlers.onRemove(entry)}
      />
      <Action
        title="Clear Recorded History"
        icon={Icon.Trash}
        style={Action.Style.Destructive}
        onAction={handlers.onClearHistory}
      />
      <Action
        title="Reload"
        icon={Icon.ArrowClockwise}
        onAction={handlers.onReload}
      />
    </ActionPanel>
  );
}

function ThreadView({
  thread,
  handlers,
}: {
  thread: Thread;
  handlers: Handlers;
}) {
  const [entries, setEntries] = useState(thread.entries);
  const scoped: Handlers = {
    ...handlers,
    onRemove: (entry) => {
      setEntries((current) => current.filter((e) => e !== entry));
      handlers.onRemove(entry);
    },
  };
  return (
    <List
      navigationTitle={`${thread.sender} · ${thread.app}`}
      searchBarPlaceholder={`Search ${entries.length} notifications`}
    >
      {entries.map((entry, index) => (
        <List.Item
          key={`${entry.ts}-${index}`}
          icon={{ source: thread.icon, fallback: Icon.Bell }}
          title={messageText(entry.body) || entry.summary}
          accessories={[
            ...urgentTag(entry.urgency),
            { text: relativeTime(entry.ts) },
          ]}
          actions={<EntryActions entry={entry} handlers={scoped} />}
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
      setEntries(await readHistory());
      setError(null);
    } catch (e: unknown) {
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    load();
    getApplications()
      .then(setApps)
      .catch(() => setApps([]));
  }, [load]);

  const handlers: Handlers = useMemo(
    () => ({
      onRemove: async (entry) => {
        await removeFromHistory(entry);
        await load();
        await showToast({ style: Toast.Style.Success, title: "Removed" });
      },
      onClearHistory: async () => {
        await clearHistory();
        await load();
        await showToast({ style: Toast.Style.Success, title: "History cleared" });
      },
      onReload: load,
    }),
    [load],
  );

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
        {items.map((entry, index) => {
          const identity = identityOf(entry, apps);
          return (
            <List.Item
              key={`${entry.ts}-${index}`}
              icon={{ source: identity.icon, fallback: Icon.Bell }}
              title={entry.summary || "(no summary)"}
              subtitle={messageText(entry.body)}
              keywords={[identity.name]}
              accessories={[
                ...urgentTag(entry.urgency),
                { text: identity.name },
                { text: relativeTime(entry.ts) },
              ]}
              actions={<EntryActions entry={entry} handlers={handlers} />}
            />
          );
        })}
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
              push(<ThreadView thread={thread} handlers={handlers} />)
            }
          />
          <Action.CopyToClipboard
            title="Copy Latest Message"
            content={messageText(thread.latest.body)}
          />
          <Action
            title="Clear Recorded History"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={handlers.onClearHistory}
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
