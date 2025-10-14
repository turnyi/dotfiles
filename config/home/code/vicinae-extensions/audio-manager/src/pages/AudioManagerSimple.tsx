import React, { useState, useMemo } from "react";
import {
  Icon,
  confirmAlert,
  Keyboard,
  List,
  ActionPanel,
  Action,
} from "@vicinae/api";
import { useAudio } from "../hooks/useAudio";
import { AudioDevice } from "../types/audio";
import { getDeviceTypeIcon, getVolumeIcon, AudioIcons } from "../helpers/icons";

export function AudioManagerSimple() {
  const {
    sinks,
    sources,
    defaultSink,
    defaultSource,
    loading,
    error,
    operationInProgress,
    setDefaultDevice,
    setVolume,
    increaseVolume,
    decreaseVolume,
    toggleMute,
    testDevice,
    refresh,
  } = useAudio();

  const getDeviceIcon = (device: AudioDevice) => {
    if (device.isDefault) return AudioIcons.Default;
    if (device.muted) return AudioIcons.Muted;
    if (device.type === "sink") {
      return device.name.toLowerCase().includes("headphone")
        ? AudioIcons.Headphones
        : AudioIcons.Speaker;
    } else {
      return AudioIcons.Microphone;
    }
  };

  const getSubtitle = (device: AudioDevice) => {
    const parts = [];
    if (device.isDefault) parts.push("Default");
    if (device.muted) parts.push("Muted");
    else parts.push(`${device.volume}%`);
    parts.push(device.status);
    return parts.join(" • ");
  };

  const getAccessories = (device: AudioDevice) => {
    const accessories = [];

    // Simple volume bar without real-time updates
    const bars = Math.ceil(device.volume / 10);
    const volumeBar = device.muted
      ? "✕"
      : "■".repeat(Math.max(1, bars)) + "□".repeat(Math.max(0, 10 - bars));
    accessories.push({ text: volumeBar });

    if (device.isDefault) {
      accessories.push({ tag: { value: "Default", color: "#00ff00" } });
    }

    if (device.muted) {
      accessories.push({ tag: { value: "Muted", color: "#ff6666" } });
    } else {
      accessories.push({ text: `${device.volume}%` });
    }

    return accessories;
  };

  const getActions = (device: AudioDevice) => {
    const actions = [];

    if (!device.isDefault) {
      actions.push({
        title: `Set as Default ${device.type === "sink" ? "Output" : "Input"}`,
        icon: AudioIcons.Default,
        onAction: () => setDefaultDevice(device.id, device.type),
      });
    }

    actions.push({
      title: device.muted ? "Unmute" : "Mute",
      icon: device.muted ? Icon.SpeakerX : Icon.SpeakerSlash,
      onAction: () => toggleMute(device.id, device.type),
    });

    // Volume increment/decrement controls
    actions.push({
      title: "Volume +10%",
      icon: "▲",
      onAction: () => increaseVolume(device.id, device.type, 10),
      shortcut: { key: "ArrowUp", modifiers: [] } as Keyboard.Shortcut,
    });

    actions.push({
      title: "Volume -10%",
      icon: "▼",
      onAction: () => decreaseVolume(device.id, device.type, 10),
      shortcut: { key: "ArrowDown", modifiers: [] } as Keyboard.Shortcut,
    });

    if (!device.muted) {
      actions.push({
        title: "Volume 100%",
        icon: AudioIcons.VolumeHigh,
        onAction: () => setVolume(device.id, device.type, 100),
      });

      actions.push({
        title: "Volume 50%",
        icon: AudioIcons.VolumeMedium,
        onAction: () => setVolume(device.id, device.type, 50),
      });

      actions.push({
        title: "Volume 0%",
        icon: AudioIcons.VolumeOff,
        onAction: () => setVolume(device.id, device.type, 0),
      });
    }

    if (device.type === "sink") {
      actions.push({
        title: "Test Audio",
        icon: AudioIcons.Audio,
        onAction: () => testDevice(device.id),
      });
    }

    return actions;
  };

  // Memoize items to prevent unnecessary re-renders
  const sinkItems = useMemo(
    () =>
      sinks.map((device) => (
        <List.Item
          key={device.id}
          title={device.name}
          subtitle={getSubtitle(device)}
          icon={getDeviceIcon(device)}
          accessories={getAccessories(device)}
          actions={
            <ActionPanel>
              {getActions(device).map((action, index) => (
                <Action
                  key={index}
                  title={action.title}
                  icon={action.icon}
                  onAction={action.onAction}
                />
              ))}
              <Action
                title="Refresh Devices"
                icon={Icon.ArrowClockwise}
                onAction={refresh}
                shortcut={{ key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut}
              />
            </ActionPanel>
          }
        />
      )),
    [sinks, setDefaultDevice, toggleMute, setVolume, testDevice, refresh],
  );

  const sourceItems = useMemo(
    () =>
      sources.map((device) => (
        <List.Item
          key={device.id}
          title={device.name}
          subtitle={getSubtitle(device)}
          icon={getDeviceIcon(device)}
          accessories={getAccessories(device)}
          actions={
            <ActionPanel>
              {getActions(device).map((action, index) => (
                <Action
                  key={index}
                  title={action.title}
                  icon={action.icon}
                  onAction={action.onAction}
                />
              ))}
              <Action
                title="Refresh Devices"
                icon={Icon.ArrowClockwise}
                onAction={refresh}
                shortcut={{ key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut}
              />
            </ActionPanel>
          }
        />
      )),
    [sources, setDefaultDevice, toggleMute, setVolume, refresh],
  );

  const hasAnyDevices = sinks.length > 0 || sources.length > 0;

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder="Search audio devices..."
      actions={
        <ActionPanel>
          <Action
            title="Refresh Devices"
            icon={Icon.ArrowClockwise}
            onAction={refresh}
            shortcut={{ key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut}
          />
        </ActionPanel>
      }
    >
      {error ? (
        <List.EmptyView icon="⚠️" title="Error" description={error} />
      ) : !loading && !hasAnyDevices ? (
        <List.EmptyView
          icon="🎵"
          title="No Audio Devices Found"
          description="No audio devices found. Check if PulseAudio is running and devices are connected."
        />
      ) : (
        <>
          {sinks.length > 0 && (
            <List.Section title="Output Devices (Speakers/Headphones)">
              {sinkItems}
            </List.Section>
          )}

          {sources.length > 0 && (
            <List.Section title="Input Devices (Microphones)">
              {sourceItems}
            </List.Section>
          )}
        </>
      )}
    </List>
  );
}
