export interface BaseDevice {
  name: string;
  id: string;
  connected: boolean;
  known: boolean;
}

export interface NetworkAction {
  title: string;
  icon: string;
  onAction: () => void;
  style?: "primary" | "destructive";
  shortcut?: { modifiers: string[]; key: string };
}

export type ConnectionStatus =
  | "connected"
  | "disconnected"
  | "connecting"
  | "unknown";

export interface NetworkStats {
  signal?: number;
  signalStrength?: "Strong" | "Good" | "Fair" | "Weak";
}
