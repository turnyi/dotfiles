import React, { useState } from "react";
import { List, ActionPanel, Action, Keyboard } from "@vicinae/api";
import { AudioDevice } from "../types/audio";
import { AudioLevelMeter } from "./AudioLevelMeter";
import { DeviceInfoPanel } from "./DeviceInfoPanel";

interface AudioAction {
  title: string;
  icon: string;
  onAction: () => void;
  style?: "primary" | "destructive";
  shortcut?: Keyboard.Shortcut;
}

interface DeviceListProps {
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
  showDeviceDetails?: boolean;
}

export function DeviceList({
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
  showDeviceDetails = false,
}: DeviceListProps) {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const getEnhancedAccessories = (device: AudioDevice) => {
    const baseAccessories = getAccessories(device);
    const isSelected = selectedId === device.id;

    if (isSelected) {
      return [{ icon: "●", tooltip: "Selected" }, ...baseAccessories];
    }

    return baseAccessories;
  };

  const globalActionsComponent = (actions: AudioAction[]) =>
    actions.map((action, index) => (
      <Action
        key={index}
        title={action.title}
        icon={action.icon}
        onAction={action.onAction}
        style={action.style}
        shortcut={action.shortcut}
      />
    ));

  const hasAnyDevices = sinks.length > 0 || sources.length > 0;

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder={searchPlaceholder}
      actions={
        globalActions.length > 0 ? (
          <ActionPanel>{globalActionsComponent(globalActions)}</ActionPanel>
        ) : undefined
      }
    >
      {error ? (
        <List.EmptyView
          icon="⚠️"
          title="Error"
          description={error}
          actions={
            <ActionPanel>{globalActionsComponent(globalActions)}</ActionPanel>
          }
        />
      ) : !loading && !hasAnyDevices ? (
        <List.EmptyView
          icon="🎵"
          title="No Audio Devices Found"
          description={emptyMessage}
          actions={
            <ActionPanel>{globalActionsComponent(globalActions)}</ActionPanel>
          }
        />
      ) : (
        <>
          {sinks.length > 0 && (
            <List.Section title="Output Devices (Speakers/Headphones)">
              {sinks.map((device) => (
                <List.Item
                  key={device.id}
                  title={device.name}
                  subtitle={getSubtitle(device)}
                  icon={getIcon(device)}
                  accessories={getEnhancedAccessories(device)}
                  actions={
                    <ActionPanel>
                      {globalActionsComponent([
                        ...getActions(device),
                        ...globalActions,
                      ])}
                    </ActionPanel>
                  }
                />
              ))}
            </List.Section>
          )}

          {sources.length > 0 && (
            <List.Section title="Input Devices (Microphones)">
              {sources.map((device) => (
                <List.Item
                  key={device.id}
                  title={device.name}
                  subtitle={getSubtitle(device)}
                  icon={getIcon(device)}
                  accessories={getEnhancedAccessories(device)}
                  actions={
                    <ActionPanel>
                      {globalActionsComponent([
                        ...getActions(device),
                        ...globalActions,
                      ])}
                    </ActionPanel>
                  }
                />
              ))}
            </List.Section>
          )}
        </>
      )}
    </List>
  );
}
