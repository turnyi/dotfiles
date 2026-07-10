export interface WifiNetwork {
  inUse: boolean;
  ssid: string;
  bssid: string;
  mode: string;
  channel: number;
  rate: string;
  signal: number;
  security: string;
}

export interface SavedNetwork {
  name: string;
  uuid: string;
  device: string;
  timestamp: number;
}
