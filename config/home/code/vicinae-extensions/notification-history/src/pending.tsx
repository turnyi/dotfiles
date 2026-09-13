import {
  Action,
  ActionPanel,
  Application,
  Icon,
  List,
  getApplications,
  showToast,
  Toast,
} from "@vicinae/api";
import React, { useCallback, useEffect, useState } from "react";
import {
  Entry,
  dismissAll,
  dismissNotification,
  identityOf,
  messageText,
  readPending,
  relativeTime,
  urgentTag,
} from "./shared";

export default function Command() {
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [apps, setApps] = useState<Application[]>([]);

  const load = useCallback(async () => {
    setEntries(await readPending());
  }, []);

  useEffect(() => {
    load();
    getApplications()
      .then(setApps)
      .catch(() => setApps([]));
  }, [load]);

  const dismiss = useCallback(
    async (entry: Entry) => {
      setEntries((current) => (current ?? []).filter((e) => e.id !== entry.id));
      try {
        await dismissNotification(entry.id as number);
      } catch (e: unknown) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Could not dismiss",
          message: String(e),
        });
        await load();
      }
    },
    [load],
  );

  const dismissEverything = useCallback(async () => {
    await dismissAll();
    setEntries([]);
    await showToast({
      style: Toast.Style.Success,
      title: "All notifications dismissed",
    });
  }, []);

  const isLoading = entries === null;
  const items = entries ?? [];

  if (!isLoading && items.length === 0) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Checkmark}
          title="No pending notifications"
          actions={
            <ActionPanel>
              <Action
                title="Reload"
                icon={Icon.ArrowClockwise}
                onAction={load}
              />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search pending notifications">
      {items.map((entry) => {
        const identity = identityOf(entry, apps);
        return (
          <List.Item
            key={`${entry.id}`}
            icon={{ source: identity.icon, fallback: Icon.Bell }}
            title={entry.summary || "(no summary)"}
            subtitle={messageText(entry.body)}
            keywords={[identity.name]}
            accessories={[
              ...urgentTag(entry.urgency),
              { text: identity.name },
              { text: relativeTime(entry.ts) },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title="Dismiss"
                  icon={Icon.XMarkCircle}
                  onAction={() => dismiss(entry)}
                />
                <Action
                  title="Dismiss All"
                  icon={Icon.Trash}
                  style={Action.Style.Destructive}
                  shortcut={{ modifiers: ["ctrl", "shift"], key: "x" }}
                  onAction={dismissEverything}
                />
                <Action.CopyToClipboard
                  title="Copy Message"
                  content={messageText(entry.body)}
                />
                <Action
                  title="Reload"
                  icon={Icon.ArrowClockwise}
                  onAction={load}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
