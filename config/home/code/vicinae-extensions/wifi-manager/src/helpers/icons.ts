import { Icon } from "@vicinae/api";

export const NetworkIcons = {
  // WiFi Icons
  Wifi: Icon.Wifi,
  WifiDisabled: Icon.WifiDisabled,

  // Signal Strength Icons
  Signal1: Icon.Signal1,
  Signal2: Icon.Signal2,
  Signal3: Icon.Signal3,
  FullSignal: Icon.FullSignal,

  // Network Security Icons
  Lock: Icon.Lock,
  LockDisabled: Icon.LockDisabled,
  Globe: Icon.Globe,

  // Connection Status Icons
  Connected: Icon.CheckCircle,
  Disconnected: Icon.XMarkCircle,
  Known: Icon.Star,
  Unknown: Icon.Circle,
} as const;

export const BluetoothIcons = {
  // Main Bluetooth Icon
  Bluetooth: Icon.Bluetooth,

  // Device Type Icons
  Audio: Icon.Headphones,
  Airpods: Icon.Airpods,
  Speaker: Icon.SpeakerOn,
  Input: Icon.Mouse,
  Keyboard: Icon.Keyboard,
  Phone: Icon.Mobile,
  Computer: Icon.Desktop,
  Monitor: Icon.Monitor,
  Unknown: Icon.Circle,

  // Connection Status Icons
  Connected: Icon.CheckCircle,
  Paired: Icon.Star,
  Unpaired: Icon.Circle,
} as const;

export const BatteryIcons = {
  // Battery Level Icons
  Full: Icon.Battery,
  Charging: Icon.BatteryCharging,
  Low: Icon.BatteryDisabled,
  Empty: Icon.BatteryDisabled,

  // Battery Percentage Circles (for visual percentage)
  Progress100: Icon.CircleProgress100,
  Progress75: Icon.CircleProgress75,
  Progress50: Icon.CircleProgress50,
  Progress25: Icon.CircleProgress25,
  Progress0: Icon.Circle,
} as const;

export const ActionIcons = {
  // Connection Actions
  Connect: Icon.Wifi,
  Disconnect: Icon.XMarkCircle,
  Scan: Icon.ArrowClockwise,
  Rescan: Icon.ArrowClockwise,

  // Device Actions
  Pair: Icon.Link,
  Unpair: Icon.Trash,
  Forget: Icon.Trash,

  // Navigation Actions
  Back: Icon.ArrowLeft,
  Forward: Icon.ArrowRight,
  Refresh: Icon.ArrowClockwise,

  // General Actions
  Settings: Icon.Cog,
  Info: Icon.Info,
  Warning: Icon.Warning,
  Error: Icon.Exclamationmark,
} as const;

export const SystemIcons = {
  // Power and System
  Power: Icon.Power,
  Settings: Icon.Cog,
  Terminal: Icon.Terminal,

  // Status Indicators
  Success: Icon.CheckCircle,
  Error: Icon.XMarkCircle,
  Warning: Icon.Warning,
  Info: Icon.Info,
  Loading: Icon.ArrowClockwise,
} as const;

// Helper functions for dynamic icon selection
export const getSignalIcon = (strength: number): string => {
  if (strength >= 75) return NetworkIcons.FullSignal;
  if (strength >= 50) return NetworkIcons.Signal3;
  if (strength >= 25) return NetworkIcons.Signal2;
  return NetworkIcons.Signal1;
};

export const getBatteryIcon = (
  percentage: number,
  isCharging = false,
): string => {
  if (isCharging) return BatteryIcons.Charging;
  if (percentage >= 75) return BatteryIcons.Full;
  if (percentage >= 25) return BatteryIcons.Full;
  return BatteryIcons.Low;
};

export const getBatteryProgressIcon = (percentage: number): string => {
  if (percentage >= 90) return BatteryIcons.Progress100;
  if (percentage >= 65) return BatteryIcons.Progress75;
  if (percentage >= 40) return BatteryIcons.Progress50;
  if (percentage >= 15) return BatteryIcons.Progress25;
  return BatteryIcons.Progress0;
};

export const getBluetoothDeviceIcon = (deviceType: string): string => {
  switch (deviceType.toLowerCase()) {
    case "audio":
    case "headphones":
    case "headset":
    case "speaker":
      return BluetoothIcons.Audio;
    case "airpods":
    case "earbuds":
      return BluetoothIcons.Airpods;
    case "input":
    case "mouse":
      return BluetoothIcons.Input;
    case "keyboard":
      return BluetoothIcons.Keyboard;
    case "phone":
    case "mobile":
      return BluetoothIcons.Phone;
    case "computer":
    case "laptop":
    case "desktop":
      return BluetoothIcons.Computer;
    case "monitor":
    case "display":
      return BluetoothIcons.Monitor;
    default:
      return BluetoothIcons.Unknown;
  }
};
