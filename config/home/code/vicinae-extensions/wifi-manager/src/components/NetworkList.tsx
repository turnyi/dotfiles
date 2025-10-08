import React from "react";
import { List, ActionPanel, Action, Keyboard } from "@vicinae/api";
import { BaseDevice } from "../types/common";

interface NetworkAction {
  title: string;
  icon: string;
  onAction: () => void;
  style?: "primary" | "destructive";
  shortcut?: Keyboard.Shortcut;
}

interface NetworkListProps<T extends BaseDevice> {
  items: T[];
  loading: boolean;
  searchPlaceholder: string;
  getIcon: (item: T) => string;
  getSubtitle: (item: T) => string;
  getAccessories: (item: T) => any[];
  getActions: (item: T) => NetworkAction[];
  sections: Array<{
    title: string;
    items: T[];
  }>;
  globalActions?: NetworkAction[];
  error?: string | null;
  emptyMessage?: string;
}

export function NetworkList<T extends BaseDevice>({
  loading,
  searchPlaceholder,
  getIcon,
  getSubtitle,
  getAccessories,
  getActions,
  sections,
  globalActions = [],
  error,
  emptyMessage = "No items found",
}: NetworkListProps<T>) {
  const globalActionsComponent = (actions: NetworkAction[]) => actions.map((action, index) => (
    <Action
      key={index}
      title={action.title}
      icon={action.icon}
      onAction={action.onAction}
      style={action.style}
      shortcut={action.shortcut}
    />
  ));

  const hasAnyItems = sections.some(section => section.items.length > 0);

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder={searchPlaceholder}
      actions={
        globalActions.length > 0 ? (
          <ActionPanel>
            {globalActionsComponent(globalActions)}
          </ActionPanel>
        ) : undefined
      }
    >
      {error ? (
        <List.EmptyView
          icon="⚠️"
          title="Error"
          description={error}
          actions={
            <ActionPanel>
              {globalActionsComponent(globalActions)}
            </ActionPanel>
          }
        />
      ) : !loading && !hasAnyItems ? (
        <List.EmptyView
          icon="📡"
          title="No Networks Found"
          description={emptyMessage}
          actions={
            <ActionPanel>
              {globalActionsComponent(globalActions)}
            </ActionPanel>
          }
        />
      ) : (
        sections.map((section) =>
          section.items.length > 0 ? (
            <List.Section key={section.title} title={section.title}>
              {section.items.map((item) => (
                <List.Item
                  key={item.id}
                  title={item.name}
                  subtitle={getSubtitle(item)}
                  icon={getIcon(item)}
                  accessories={getAccessories(item)}
                  actions={
                    <ActionPanel>
                      {globalActionsComponent([...getActions(item), ...globalActions])}
                    </ActionPanel>
                  }
                />
              ))}
            </List.Section>
          ) : null,
        )
      )}
    </List>
  );
}
