import { Color, Icon } from "@vicinae/api";

export function signalIcon(signal: number) {
  if (signal >= 75) return Icon.FullSignal;
  if (signal >= 50) return Icon.Signal3;
  if (signal >= 25) return Icon.Signal2;
  return Icon.Signal1;
}

export function signalColor(signal: number): Color {
  if (signal >= 65) return Color.Green;
  if (signal >= 35) return Color.Orange;
  return Color.Red;
}

export function signalLabel(signal: number): string {
  if (signal >= 80) return "Excellent";
  if (signal >= 60) return "Good";
  if (signal >= 40) return "Fair";
  if (signal >= 20) return "Weak";
  return "Poor";
}

export function signalBars(signal: number): string {
  const chars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
  const filled = Math.round((signal / 100) * chars.length);
  return chars.slice(0, filled).join("") + "░".repeat(chars.length - filled);
}

export function frequencyBand(channel: number): string {
  if (channel >= 1 && channel <= 14) return "2.4 GHz";
  if (channel >= 32) return "5 GHz";
  return "";
}

export function isOpen(security: string): boolean {
  return !security || /^(open|--|)$/i.test(security.trim());
}

export function buildWifiQrString(ssid: string, password: string, security: string): string {
  const esc = (s: string) => s.replace(/[\\;,":]/g, "\\$&");
  const type = /wpa/i.test(security) ? "WPA" : /wep/i.test(security) ? "WEP" : "nopass";
  return `WIFI:T:${type};S:${esc(ssid)};P:${esc(password)};;`;
}
