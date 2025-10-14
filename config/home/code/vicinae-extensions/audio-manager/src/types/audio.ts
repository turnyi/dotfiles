import { BaseDevice, VolumeControl, DeviceStatus } from "./common";

export interface AudioDevice extends BaseDevice, VolumeControl {
  description: string;
  type: "sink" | "source";
  isDefault: boolean;
  status: DeviceStatus;
  driver?: string;
  ports?: AudioPort[];
  hardwareInfo?: AudioHardwareInfo;
  currentLevel?: number;
  peakLevel?: number;
  hasActiveStreams?: boolean;
}

export interface AudioPort {
  name: string;
  description: string;
  available: boolean;
  active: boolean;
}

export interface AudioDeviceInfo {
  sinks: AudioDevice[];
  sources: AudioDevice[];
  defaultSink?: string;
  defaultSource?: string;
}

export interface AudioOperationResult {
  success: boolean;
  message?: string;
}

export interface VolumeChangeEvent {
  deviceId: string;
  volume: number;
  muted: boolean;
}

export interface AudioHardwareInfo {
  sampleFormat?: string;
  sampleRate?: string;
  channels?: string;
  channelMap?: string;
  activePort?: string;
  availablePorts?: string[];
  cardName?: string;
  connectionType?:
    | "usb"
    | "bluetooth"
    | "internal"
    | "hdmi"
    | "analog"
    | "unknown";
  latency?: string;
}

export interface AudioLevelData {
  deviceId: string;
  currentLevel: number;
  peakLevel: number;
  timestamp: number;
}

export interface ActiveAudioStream {
  id: string;
  applicationName: string;
  deviceId: string;
  volume: number;
  muted: boolean;
  type: "playback" | "recording";
}

export interface AudioMonitoringData {
  levels: Record<string, AudioLevelData>;
  activeStreams: ActiveAudioStream[];
  lastUpdate: number;
}
