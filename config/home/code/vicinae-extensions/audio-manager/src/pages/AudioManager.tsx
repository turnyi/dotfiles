import React, { useState } from "react";
import { Icon, confirmAlert, Keyboard } from "@vicinae/api";
import { useAudio } from "../hooks/useAudio";
import { useAudioMonitoring } from "../hooks/useAudioMonitoring";
import { AudioDevice } from "../types/audio";
import { DeviceList } from "../components/DeviceList";
import { AudioLevelMeter } from "../components/AudioLevelMeter";
import { DeviceInfoPanel } from "../components/DeviceInfoPanel";
import { getDeviceTypeIcon, getVolumeIcon, AudioIcons } from "../helpers/icons";

export function AudioManager() {
  const [showLevelMeters, setShowLevelMeters] = useState(true);
  const [monitoringEnabled, setMonitoringEnabled] = useState(true);

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
    toggleMute,
    testDevice,
    refresh,
  } = useAudio();

  // Use monitoring hook to get enhanced device data with level information
  const {
    enhancedDevices: allDevices,
    isMonitoring,
    startMonitoring,
    stopMonitoring,
  } = useAudioMonitoring({
    devices: [...sinks, ...sources],
    enabled: monitoringEnabled,
    updateInterval: 1000,
  });

  // Split enhanced devices back into sinks and sources
  const enhancedSinks = allDevices.filter((d) => d.type === "sink");
  const enhancedSources = allDevices.filter((d) => d.type === "source");

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

    // Add audio level information if available
    if (device.currentLevel !== undefined) {
      const levelText =
        device.currentLevel > 0
          ? `Level: ${device.currentLevel.toFixed(0)}%`
          : "Silent";
      parts.push(levelText);
    }

    if (device.hasActiveStreams) {
      parts.push("🎵 Active");
    }

    parts.push(device.status);

    return parts.join(" • ");
  };

  const getAccessories = (device: AudioDevice) => {
    const accessories = [];

    // Audio level meter (compact version)
    if (
      showLevelMeters &&
      (device.currentLevel !== undefined || device.volume !== undefined)
    ) {
      accessories.push({
        text:
          device.currentLevel !== undefined
            ? `🎵 ${device.currentLevel.toFixed(0)}%`
            : `🔊 ${device.volume}%`,
      });
    }

    // Volume bar visualization
    const bars = Math.ceil(device.volume / 10);
    const volumeBar = device.muted
      ? "🔇"
      : "█".repeat(Math.max(1, bars)) + "░".repeat(Math.max(0, 10 - bars));
    accessories.push({ text: volumeBar });

    // Status indicators
    if (device.isDefault) {
      accessories.push({ tag: { value: "Default", color: "#00ff00" } });
    }

    if (device.hasActiveStreams) {
      accessories.push({ tag: { value: "Active", color: "#4CAF50" } });
    }

    if (device.muted) {
      accessories.push({ tag: { value: "Muted", color: "#ff6666" } });
    } else {
      accessories.push({ text: `${device.volume}%` });
    }

    const actionHint = device.isDefault
      ? device.muted
        ? "⏎ Unmute"
        : "⏎ Mute"
      : "⏎ Set Default";

    accessories.push({
      text: actionHint,
      tooltip: "Press Enter to perform this action",
    });

    return accessories;
  };

  const getActions = (device: AudioDevice) => {
    const actions = [];

    // Primary action - set as default or toggle mute
    if (!device.isDefault) {
      actions.push({
        title: `Set as Default ${device.type === "sink" ? "Output" : "Input"}`,
        icon: AudioIcons.Default,
        onAction: () => setDefaultDevice(device.id, device.type),
      });
    }

    // Mute/Unmute toggle
    actions.push({
      title: device.muted ? "Unmute" : "Mute",
      icon: device.muted ? Icon.SpeakerX : Icon.SpeakerSlash,
      onAction: () => toggleMute(device.id, device.type),
    });

    // Volume controls
    if (!device.muted) {
      actions.push({
        title: "Volume 100%",
        icon: AudioIcons.VolumeHigh,
        onAction: () => setVolume(device.id, device.type, 100),
      });

      actions.push({
        title: "Volume 75%",
        icon: AudioIcons.VolumeMedium,
        onAction: () => setVolume(device.id, device.type, 75),
      });

      actions.push({
        title: "Volume 50%",
        icon: AudioIcons.VolumeMedium,
        onAction: () => setVolume(device.id, device.type, 50),
      });

      actions.push({
        title: "Volume 25%",
        icon: AudioIcons.VolumeLow,
        onAction: () => setVolume(device.id, device.type, 25),
      });
    }

    // Test device (for output devices only)
    if (device.type === "sink") {
      actions.push({
        title: "Test Audio",
        icon: AudioIcons.Audio,
        onAction: () => testDevice(device.id),
      });
    }

    return actions;
  };

  const globalActions = [
    {
      title: "Refresh Devices",
      icon: Icon.ArrowClockwise,
      onAction: refresh,
      shortcut: { key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut,
    },
    {
      title: isMonitoring ? "Stop Monitoring" : "Start Monitoring",
      icon: isMonitoring ? Icon.Pause : Icon.Play,
      onAction: () => {
        if (isMonitoring) {
          stopMonitoring();
          setMonitoringEnabled(false);
        } else {
          startMonitoring();
          setMonitoringEnabled(true);
        }
      },
      shortcut: { key: "m", modifiers: ["cmd"] } as Keyboard.Shortcut,
    },
    {
      title: showLevelMeters ? "Hide Level Meters" : "Show Level Meters",
      icon: showLevelMeters ? Icon.EyeSlash : Icon.Eye,
      onAction: () => setShowLevelMeters(!showLevelMeters),
      shortcut: { key: "l", modifiers: ["cmd"] } as Keyboard.Shortcut,
    },
  ];

  // Add quick mute all actions
  if (sinks.length > 0 || sources.length > 0) {
    globalActions.push({
      title: "Mute All Outputs",
      icon: Icon.SpeakerSlash,
      onAction: async () => {
        const confirmed = await confirmAlert({
          title: "Mute All Outputs",
          message: "Are you sure you want to mute all output devices?",
          primaryAction: { title: "Mute All" },
        });

        if (confirmed) {
          sinks.forEach((device) => {
            if (!device.muted) {
              toggleMute(device.id, device.type, true);
            }
          });
        }
      },
      style: "destructive" as const,
    });

    globalActions.push({
      title: "Mute All Inputs",
      icon: Icon.MicrophoneSlash,
      onAction: async () => {
        const confirmed = await confirmAlert({
          title: "Mute All Inputs",
          message: "Are you sure you want to mute all input devices?",
          primaryAction: { title: "Mute All" },
        });

        if (confirmed) {
          sources.forEach((device) => {
            if (!device.muted) {
              toggleMute(device.id, device.type, true);
            }
          });
        }
      },
      style: "destructive" as const,
    });
  }

  return (
    <DeviceList
      sinks={enhancedSinks}
      sources={enhancedSources}
      loading={loading}
      searchPlaceholder="Search audio devices..."
      getIcon={getDeviceIcon}
      getSubtitle={getSubtitle}
      getAccessories={getAccessories}
      getActions={getActions}
      globalActions={globalActions}
      error={error}
      emptyMessage="No audio devices found. Check if PulseAudio is running and devices are connected."
      showLevelMeters={showLevelMeters}
      showDeviceDetails={false}
    />
  );
}
