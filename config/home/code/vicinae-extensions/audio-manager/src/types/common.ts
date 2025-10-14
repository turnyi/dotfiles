export interface BaseDevice {
  name: string;
  id: string;
  connected: boolean;
  known: boolean;
}

export interface AudioAction {
  title: string;
  icon: string;
  onAction: () => void;
  style?: "primary" | "destructive";
  shortcut?: { modifiers: string[]; key: string };
}

export type DeviceStatus = "active" | "idle" | "suspended" | "unknown";

export interface VolumeControl {
  volume: number;
  muted: boolean;
}
