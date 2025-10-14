export const AudioIcons = {
  Speaker: "♪",
  Microphone: "◉",
  Headphones: "♫",
  Muted: "✕",
  VolumeHigh: "◐",
  VolumeMedium: "◑",
  VolumeLow: "◒",
  VolumeOff: "○",
  Default: "●",
  Connected: "●",
  Disconnected: "○",
  Audio: "♪",
  Settings: "⚙",
  Refresh: "↻",
} as const;

export const DeviceTypeIcons = {
  "analog-output-speaker": "♪",
  "analog-output-headphones": "♫",
  "analog-input-microphone": "◉",
  "analog-input-linein": "◎",
  "hdmi-output": "▣",
  "usb-audio": "◈",
  bluetooth: "◈",
  "builtin-audio": "■",
  unknown: "○",
} as const;

export const getVolumeIcon = (volume: number, muted: boolean): string => {
  if (muted) return AudioIcons.VolumeOff;
  if (volume >= 70) return AudioIcons.VolumeHigh;
  if (volume >= 30) return AudioIcons.VolumeMedium;
  if (volume > 0) return AudioIcons.VolumeLow;
  return AudioIcons.VolumeOff;
};

export const getDeviceTypeIcon = (deviceType: string): string => {
  for (const [key, icon] of Object.entries(DeviceTypeIcons)) {
    if (deviceType.toLowerCase().includes(key)) {
      return icon;
    }
  }
  return DeviceTypeIcons.unknown;
};
