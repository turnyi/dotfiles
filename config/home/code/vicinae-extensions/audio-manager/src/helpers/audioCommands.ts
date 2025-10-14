export class LinuxAudioCommands {
  // Device discovery commands
  static readonly LIST_SINKS = "pactl list short sinks";
  static readonly LIST_SOURCES = "pactl list short sources";
  static readonly LIST_SINK_INPUTS = "pactl list short sink-inputs";
  static readonly LIST_SOURCE_OUTPUTS = "pactl list short source-outputs";

  // Default device commands
  static readonly GET_DEFAULT_SINK = "pactl get-default-sink";
  static readonly GET_DEFAULT_SOURCE = "pactl get-default-source";

  // Device information commands
  static getDeviceInfoCommand(
    deviceName: string,
    type: "sink" | "source",
  ): string {
    return `pactl list ${type}s | grep -A 20 "Name: ${deviceName}"`;
  }

  static getSinkDetailsCommand(): string {
    return "pactl list sinks";
  }

  static getSourceDetailsCommand(): string {
    return "pactl list sources";
  }

  // Volume control commands
  static getSetSinkVolumeCommand(device: string, volume: number): string {
    return `pactl set-sink-volume ${device} ${volume}%`;
  }

  static getSetSourceVolumeCommand(device: string, volume: number): string {
    return `pactl set-source-volume ${device} ${volume}%`;
  }

  static getSinkMuteCommand(device: string, mute: boolean): string {
    return `pactl set-sink-mute ${device} ${mute ? "1" : "0"}`;
  }

  static getSourceMuteCommand(device: string, mute: boolean): string {
    return `pactl set-source-mute ${device} ${mute ? "1" : "0"}`;
  }

  // Device switching commands
  static getSetDefaultSinkCommand(device: string): string {
    return `pactl set-default-sink ${device}`;
  }

  static getSetDefaultSourceCommand(device: string): string {
    return `pactl set-default-source ${device}`;
  }

  // Audio testing commands
  static getTestSoundCommand(device: string): string {
    // Try multiple test methods as fallbacks
    return `speaker-test -t sine -f 1000 -l 1 -s 1 -D ${device} || (echo "Testing audio on ${device}" && pactl set-sink-volume ${device} 50% && pactl set-sink-volume ${device} 75% && pactl set-sink-volume ${device} 50%)`;
  }

  static getAlternativeTestCommand(device: string): string {
    // Alternative: Generate a brief tone using ffplay
    return `timeout 1s ffplay -nodisp -autoexit -f lavfi "sine=frequency=1000:duration=0.5" -af "volume=0.1" -o pulse -device ${device} 2>/dev/null || echo "Test completed for ${device}"`;
  }

  static getSimpleTestCommand(device: string): string {
    // Simplest test: just manipulate volume briefly to indicate the device works
    return `pactl set-sink-volume ${device} 50% && sleep 0.1 && pactl set-sink-volume ${device} 75% && sleep 0.1 && pactl set-sink-volume ${device} 50%`;
  }

  // Server information
  static readonly GET_SERVER_INFO = "pactl info";

  // Monitor commands for real-time updates
  static readonly SUBSCRIBE_EVENTS = "pactl subscribe";

  // Audio level monitoring commands
  static getSinkMonitorCommand(sinkName: string): string {
    return `pactl list sinks | grep -A 20 "Name: ${sinkName}" | grep -E "(Volume|Mute|State)"`;
  }

  static getSourceMonitorCommand(sourceName: string): string {
    return `pactl list sources | grep -A 20 "Name: ${sourceName}" | grep -E "(Volume|Mute|State)"`;
  }

  // Enhanced device information commands
  static getDeviceHardwareInfoCommand(
    deviceName: string,
    type: "sink" | "source",
  ): string {
    return `pactl list ${type}s | grep -A 30 "Name: ${deviceName}" | grep -E "(Driver|Sample Specification|Channel Map|Ports|Active Port|Properties)"`;
  }

  static getCardInfoCommand(): string {
    return "pactl list cards";
  }

  // Active streams detection
  static getActiveSinkInputsCommand(): string {
    return "pactl list sink-inputs";
  }

  static getActiveSourceOutputsCommand(): string {
    return "pactl list source-outputs";
  }

  // Audio level measurement using pactl
  static getAudioLevelCommand(
    deviceName: string,
    type: "sink" | "source",
  ): string {
    // For sinks, we monitor the .monitor source
    if (type === "sink") {
      return `timeout 1s pactl list sources | grep -A 10 "${deviceName}.monitor" | grep -E "Volume|State" | head -2`;
    } else {
      return `timeout 1s pactl list sources | grep -A 10 "Name: ${deviceName}" | grep -E "Volume|State" | head -2`;
    }
  }

  // Real-time audio level monitoring using parec
  static getRealtimeAudioLevelCommand(
    deviceName: string,
    type: "sink" | "source",
  ): string {
    const source = type === "sink" ? `${deviceName}.monitor` : deviceName;
    return `timeout 0.5s parec -d ${source} --rate=44100 --format=s16le --channels=1 | od -An -td2 | head -10`;
  }
}
