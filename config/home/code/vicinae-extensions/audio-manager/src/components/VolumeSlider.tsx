import React from "react";
import { ActionPanel, Action, List, Icon } from "@vicinae/api";
import { AudioDevice } from "../types/audio";
import { getVolumeIcon } from "../helpers/icons";

interface VolumeSliderProps {
  device: AudioDevice;
  onVolumeChange: (volume: number) => void;
  onToggleMute: () => void;
  disabled?: boolean;
}

export function VolumeSlider({
  device,
  onVolumeChange,
  onToggleMute,
  disabled,
}: VolumeSliderProps) {
  const volumeIcon = getVolumeIcon(device.volume, device.muted);
  const volumeSteps = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  const getVolumeActions = () => {
    const actions = [];

    // Mute toggle
    actions.push({
      title: device.muted ? "Unmute" : "Mute",
      icon: device.muted ? Icon.SpeakerSlash : Icon.Speaker3,
      onAction: onToggleMute,
    });

    // Quick volume presets
    actions.push({
      title: "Volume 100%",
      icon: "🔊",
      onAction: () => onVolumeChange(100),
    });

    actions.push({
      title: "Volume 75%",
      icon: "🔉",
      onAction: () => onVolumeChange(75),
    });

    actions.push({
      title: "Volume 50%",
      icon: "🔉",
      onAction: () => onVolumeChange(50),
    });

    actions.push({
      title: "Volume 25%",
      icon: "🔈",
      onAction: () => onVolumeChange(25),
    });

    actions.push({
      title: "Volume 0%",
      icon: "🔇",
      onAction: () => onVolumeChange(0),
    });

    return actions;
  };

  const getVolumeSubtitle = () => {
    if (device.muted) return "Muted";
    return `${device.volume}%`;
  };

  const getVolumeAccessories = () => {
    const accessories = [];

    // Volume bar visualization
    const bars = Math.ceil(device.volume / 10);
    const volumeBar = "█".repeat(bars) + "░".repeat(10 - bars);
    accessories.push({ text: volumeBar });

    // Volume percentage
    accessories.push({
      text: device.muted ? "MUTED" : `${device.volume}%`,
      tooltip: `Current volume: ${device.volume}%${device.muted ? " (Muted)" : ""}`,
    });

    return accessories;
  };

  return (
    <List.Item
      title={`Volume Control`}
      subtitle={getVolumeSubtitle()}
      icon={volumeIcon}
      accessories={getVolumeAccessories()}
      actions={
        <ActionPanel>
          {getVolumeActions().map((action, index) => (
            <Action
              key={index}
              title={action.title}
              icon={action.icon}
              onAction={action.onAction}
            />
          ))}
        </ActionPanel>
      }
    />
  );
}
