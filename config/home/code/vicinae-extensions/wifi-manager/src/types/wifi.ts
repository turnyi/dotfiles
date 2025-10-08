import { BaseDevice, NetworkStats } from "./common";

export interface WiFiNetwork extends BaseDevice, NetworkStats {
  ssid: string;
  bssid: string;
  security: string;
  frequency: string;
}

export interface WiFiConnectionResult {
  success: boolean;
  message?: string;
}
