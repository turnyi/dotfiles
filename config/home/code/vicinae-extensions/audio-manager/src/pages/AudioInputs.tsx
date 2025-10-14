import React, { useMemo } from "react";
import { Icon, Keyboard, List, ActionPanel, Action } from "@vicinae/api";
import { useAudio } from "../hooks/useAudio";
import { AudioDevice } from "../types/audio";
import { AudioIcons } from "../helpers/icons";

export function AudioInputs() {
  const {
    sources,
    loading,
    error,
    setDefaultDevice,
    setVolume,
    increaseVolume,
    decreaseVolume,
    toggleMute,
    refresh,
  } = useAudio();

  const getDeviceIcon = (device: AudioDevice) => {
    if (device.isDefault) return AudioIcons.Default;
    if (device.muted) return AudioIcons.Muted;
    return AudioIcons.Microphone;
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

    // Volume bar
    const bars = Math.ceil(device.volume / 10);
    const volumeBar = device.muted
      ? "🔇"
      : "█".repeat(Math.max(1, bars)) + "░".repeat(Math.max(0, 10 - bars));
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

    // Set as default
    if (!device.isDefault) {
      actions.push({
        title: "Set as Default Input",
        icon: AudioIcons.Default,
        onAction: () => setDefaultDevice(device.id, device.type),
        shortcut: { key: "d", modifiers: ["cmd"] } as Keyboard.Shortcut,
      });
    }

    // Mute toggle
    actions.push({
      title: device.muted ? "Unmute Microphone" : "Mute Microphone",
      icon: device.muted ? Icon.MicrophoneSlash : Icon.Microphone,
      onAction: () => toggleMute(device.id, device.type),
      shortcut: { key: "m", modifiers: [] } as Keyboard.Shortcut,
    });

    // Volume controls (gain for microphones)
    actions.push({
      title: "Gain +10%",
      icon: "▲",
      onAction: () => increaseVolume(device.id, device.type, 10),
      shortcut: { key: "ArrowUp", modifiers: [] } as Keyboard.Shortcut,
    });

    actions.push({
      title: "Gain -10%",
      icon: "▼",
      onAction: () => decreaseVolume(device.id, device.type, 10),
      shortcut: { key: "ArrowDown", modifiers: [] } as Keyboard.Shortcut,
    });

    // Quick gain presets
    if (!device.muted) {
      actions.push({
        title: "Gain 100%",
        icon: AudioIcons.VolumeHigh,
        onAction: () => setVolume(device.id, device.type, 100),
      });

      actions.push({
        title: "Gain 75%",
        icon: AudioIcons.VolumeMedium,
        onAction: () => setVolume(device.id, device.type, 75),
      });

      actions.push({
        title: "Gain 50%",
        icon: AudioIcons.VolumeMedium,
        onAction: () => setVolume(device.id, device.type, 50),
      });

      actions.push({
        title: "Gain 25%",
        icon: AudioIcons.VolumeLow,
        onAction: () => setVolume(device.id, device.type, 25),
      });

      actions.push({
        title: "Gain 0% (Silent)",
        icon: AudioIcons.VolumeOff,
        onAction: () => setVolume(device.id, device.type, 0),
      });
    }

    return actions;
  };

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
                  shortcut={action.shortcut}
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
    [
      sources,
      setDefaultDevice,
      toggleMute,
      increaseVolume,
      decreaseVolume,
      setVolume,
      refresh,
    ],
  );

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder="Search input devices..."
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
      ) : !loading && sources.length === 0 ? (
        <List.EmptyView
          icon="🎤"
          title="No Input Devices Found"
          description="No microphones or recording devices found. Check if devices are connected."
        />
      ) : (
        <List.Section
          title="Input Devices"
          subtitle={`${sources.length} device${sources.length > 1 ? "s" : ""} • Use ↑↓ for gain, M to mute`}
        >
          {sourceItems}
        </List.Section>
      )}
    </List>
  );
}
