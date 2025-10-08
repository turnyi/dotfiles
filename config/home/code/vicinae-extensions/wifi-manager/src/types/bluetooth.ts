import { BaseDevice } from "./common";

export interface BluetoothDevice extends BaseDevice {
  address: string;
  deviceType: "audio" | "input" | "phone" | "computer" | "unknown";
  paired: boolean;
  trusted: boolean;
  battery?: number;
}

export interface BluetoothConnectionResult {
  success: boolean;
  message?: string;
}
