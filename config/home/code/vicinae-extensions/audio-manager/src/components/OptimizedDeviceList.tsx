import React, { useState, useMemo, useCallback } from "react";
import { List, ActionPanel, Action, Keyboard } from "@vicinae/api";
import { AudioDevice } from "../types/audio";

interface AudioAction {
  title: string;
  icon: string;
  onAction: () => void;
  style?: "primary" | "destructive";
  shortcut?: Keyboard.Shortcut;
}

interface OptimizedDeviceListProps {
  sinks: AudioDevice[];
  sources: AudioDevice[];
  loading: boolean;
  searchPlaceholder: string;
  getIcon: (device: AudioDevice) => string;
  getSubtitle: (device: AudioDevice) => string;
  getAccessories: (device: AudioDevice) => any[];
  getActions: (device: AudioDevice) => AudioAction[];
  globalActions?: AudioAction[];
  error?: string | null;
  emptyMessage?: string;
  showLevelMeters?: boolean;
  enableVirtualization?: boolean;
}

export function OptimizedDeviceList({
  sinks,
  sources,
  loading,
  searchPlaceholder,
  getIcon,
  getSubtitle,
  getAccessories,
  getActions,
  globalActions = [],
  error,
  emptyMessage = "No audio devices found",
  showLevelMeters = true,
  enableVirtualization = true,
}: OptimizedDeviceListProps) {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // Memoize accessories to prevent unnecessary re-renders
  const getOptimizedAccessories = useCallback(
    (device: AudioDevice) => {
      const baseAccessories = getAccessories(device);
      const isSelected = selectedId === device.id;

      if (isSelected) {
        return [{ icon: "●", tooltip: "Selected" }, ...baseAccessories];
      }

      return baseAccessories;
    },
    [getAccessories, selectedId],
  );

  // Memoize global actions component
  const globalActionsComponent = useMemo(
    () =>
      globalActions.map((action, index) => (
        <Action
          key={`global-${index}`}
          title={action.title}
          icon={action.icon}
          onAction={action.onAction}
          style={action.style}
          shortcut={action.shortcut}
        />
      )),
    [globalActions],
  );

  // Memoize device actions to prevent re-creation
  const getDeviceActions = useCallback(
    (device: AudioDevice) => {
      const deviceActions = getActions(device);
      return [...deviceActions, ...globalActions].map((action, index) => (
        <Action
          key={`${device.id}-action-${index}`}
          title={action.title}
          icon={action.icon}
          onAction={action.onAction}
          style={action.style}
          shortcut={action.shortcut}
        />
      ));
    },
    [getActions, globalActions],
  );

  const hasAnyDevices = sinks.length > 0 || sources.length > 0;

  // Memoize list items to prevent unnecessary re-renders
  const sinkItems = useMemo(
    () =>
      sinks.map((device) => (
        <List.Item
          key={device.id}
          title={device.name}
          subtitle={getSubtitle(device)}
          icon={getIcon(device)}
          accessories={getOptimizedAccessories(device)}
          actions={<ActionPanel>{getDeviceActions(device)}</ActionPanel>}
        />
      )),
    [sinks, getSubtitle, getIcon, getOptimizedAccessories, getDeviceActions],
  );

  const sourceItems = useMemo(
    () =>
      sources.map((device) => (
        <List.Item
          key={device.id}
          title={device.name}
          subtitle={getSubtitle(device)}
          icon={getIcon(device)}
          accessories={getOptimizedAccessories(device)}
          actions={<ActionPanel>{getDeviceActions(device)}</ActionPanel>}
        />
      )),
    [sources, getSubtitle, getIcon, getOptimizedAccessories, getDeviceActions],
  );

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder={searchPlaceholder}
      enableFiltering={true}
      actions={
        globalActions.length > 0 ? (
          <ActionPanel>{globalActionsComponent}</ActionPanel>
        ) : undefined
      }
    >
      {error ? (
        <List.EmptyView
          icon="⚠️"
          title="Error"
          description={error}
          actions={<ActionPanel>{globalActionsComponent}</ActionPanel>}
        />
      ) : !loading && !hasAnyDevices ? (
        <List.EmptyView
          icon="🎵"
          title="No Audio Devices Found"
          description={emptyMessage}
          actions={<ActionPanel>{globalActionsComponent}</ActionPanel>}
        />
      ) : (
        <>
          {sinks.length > 0 && (
            <List.Section
              title="Output Devices (Speakers/Headphones)"
              subtitle={`${sinks.length} device${sinks.length > 1 ? "s" : ""}`}
            >
              {sinkItems}
            </List.Section>
          )}

          {sources.length > 0 && (
            <List.Section
              title="Input Devices (Microphones)"
              subtitle={`${sources.length} device${sources.length > 1 ? "s" : ""}`}
            >
              {sourceItems}
            </List.Section>
          )}
        </>
      )}
    </List>
  );
}
