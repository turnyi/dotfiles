import {
  AudioDevice,
  AudioDeviceInfo,
  AudioOperationResult,
  AudioHardwareInfo,
  AudioLevelData,
  ActiveAudioStream,
  AudioMonitoringData,
} from "../types/audio";
import { LinuxAudioCommands } from "./audioCommands";
import { execAsync, parseKeyValueOutput } from "./commandHelper";
import { getDeviceTypeIcon, getVolumeIcon } from "./icons";

export class AudioHelper {
  static async getAudioDevices(): Promise<AudioDeviceInfo> {
    try {
      console.log("Scanning audio devices...");

      const [
        sinksResult,
        sourcesResult,
        defaultSinkResult,
        defaultSourceResult,
        sinkDetailsResult,
        sourceDetailsResult,
      ] = await Promise.all([
        execAsync(LinuxAudioCommands.LIST_SINKS),
        execAsync(LinuxAudioCommands.LIST_SOURCES),
        execAsync(LinuxAudioCommands.GET_DEFAULT_SINK),
        execAsync(LinuxAudioCommands.GET_DEFAULT_SOURCE),
        execAsync(LinuxAudioCommands.getSinkDetailsCommand()),
        execAsync(LinuxAudioCommands.getSourceDetailsCommand()),
      ]);

      const defaultSink = defaultSinkResult.stdout.trim();
      const defaultSource = defaultSourceResult.stdout.trim();

      const sinks = this.parseSinksList(
        sinksResult.stdout,
        sinkDetailsResult.stdout,
        defaultSink,
      );
      const sources = this.parseSourcesList(
        sourcesResult.stdout,
        sourceDetailsResult.stdout,
        defaultSource,
      );

      console.log(`Found ${sinks.length} sinks and ${sources.length} sources`);

      return {
        sinks,
        sources,
        defaultSink,
        defaultSource,
      };
    } catch (error) {
      console.error("Failed to get audio devices:", error);
      return {
        sinks: [],
        sources: [],
      };
    }
  }

  private static parseSinksList(
    sinksOutput: string,
    detailsOutput: string,
    defaultSink: string,
  ): AudioDevice[] {
    const devices: AudioDevice[] = [];
    const lines = sinksOutput.split("\n").filter(Boolean);

    lines.forEach((line) => {
      const parts = line.split("\t");
      if (parts.length >= 2) {
        const [id, name, driver, sampleSpec, status] = parts;

        const deviceDetails = this.extractDeviceDetails(name, detailsOutput);

        devices.push({
          name: deviceDetails.description || name,
          id: name,
          description: deviceDetails.description || name,
          type: "sink",
          connected: status !== "SUSPENDED",
          known: true,
          volume: deviceDetails.volume || 0,
          muted: deviceDetails.muted || false,
          isDefault: name === defaultSink,
          status: this.mapStatus(status),
          driver,
        });
      }
    });

    return this.sortDevices(devices);
  }

  private static parseSourcesList(
    sourcesOutput: string,
    detailsOutput: string,
    defaultSource: string,
  ): AudioDevice[] {
    const devices: AudioDevice[] = [];
    const lines = sourcesOutput.split("\n").filter(Boolean);

    lines.forEach((line) => {
      const parts = line.split("\t");
      if (parts.length >= 2) {
        const [id, name, driver, sampleSpec, status] = parts;

        // Skip monitor sources (they're virtual)
        if (name.includes(".monitor")) return;

        const deviceDetails = this.extractDeviceDetails(name, detailsOutput);

        devices.push({
          name: deviceDetails.description || name,
          id: name,
          description: deviceDetails.description || name,
          type: "source",
          connected: status !== "SUSPENDED",
          known: true,
          volume: deviceDetails.volume || 0,
          muted: deviceDetails.muted || false,
          isDefault: name === defaultSource,
          status: this.mapStatus(status),
          driver,
        });
      }
    });

    return this.sortDevices(devices);
  }

  private static extractDeviceDetails(
    deviceName: string,
    detailsOutput: string,
  ): {
    description?: string;
    volume?: number;
    muted?: boolean;
  } {
    const deviceSection = this.getDeviceSection(deviceName, detailsOutput);
    if (!deviceSection) return {};

    const description = this.extractProperty(deviceSection, "Description:");
    const volumeStr = this.extractProperty(deviceSection, "Volume:");
    const muteStr = this.extractProperty(deviceSection, "Mute:");

    let volume = 0;
    if (volumeStr) {
      const volumeMatch = volumeStr.match(/(\d+)%/);
      if (volumeMatch) {
        volume = parseInt(volumeMatch[1]);
      }
    }

    return {
      description,
      volume,
      muted: muteStr === "yes",
    };
  }

  private static getDeviceSection(
    deviceName: string,
    output: string,
  ): string | null {
    const lines = output.split("\n");
    let inTargetDevice = false;
    let deviceSection = "";

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.includes(`Name: ${deviceName}`)) {
        inTargetDevice = true;
        deviceSection = line + "\n";
        continue;
      }

      if (inTargetDevice) {
        if (
          line.match(/^(Sink|Source) #/) &&
          !line.includes(`Name: ${deviceName}`)
        ) {
          break;
        }
        deviceSection += line + "\n";
      }
    }

    return inTargetDevice ? deviceSection : null;
  }

  private static extractProperty(
    section: string,
    property: string,
  ): string | undefined {
    const lines = section.split("\n");
    for (const line of lines) {
      if (line.includes(property)) {
        return line.split(property)[1]?.trim();
      }
    }
    return undefined;
  }

  private static mapStatus(
    status: string,
  ): "active" | "idle" | "suspended" | "unknown" {
    switch (status) {
      case "RUNNING":
        return "active";
      case "IDLE":
        return "idle";
      case "SUSPENDED":
        return "suspended";
      default:
        return "unknown";
    }
  }

  private static sortDevices(devices: AudioDevice[]): AudioDevice[] {
    return devices.sort((a, b) => {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      if (a.connected && !b.connected) return -1;
      if (!a.connected && b.connected) return 1;
      return a.name.localeCompare(b.name);
    });
  }

  static async setDefaultDevice(
    deviceId: string,
    type: "sink" | "source",
  ): Promise<AudioOperationResult> {
    try {
      const command =
        type === "sink"
          ? LinuxAudioCommands.getSetDefaultSinkCommand(deviceId)
          : LinuxAudioCommands.getSetDefaultSourceCommand(deviceId);

      await execAsync(command);
      return { success: true, message: `Set ${deviceId} as default ${type}` };
    } catch (error) {
      console.error(`Failed to set default ${type}:`, error);
      return { success: false, message: `Failed to set default ${type}` };
    }
  }

  static async setDeviceVolume(
    deviceId: string,
    type: "sink" | "source",
    volume: number,
  ): Promise<AudioOperationResult> {
    try {
      const command =
        type === "sink"
          ? LinuxAudioCommands.getSetSinkVolumeCommand(deviceId, volume)
          : LinuxAudioCommands.getSetSourceVolumeCommand(deviceId, volume);

      await execAsync(command);
      return { success: true, message: `Set ${deviceId} volume to ${volume}%` };
    } catch (error) {
      console.error(`Failed to set ${type} volume:`, error);
      return { success: false, message: `Failed to set ${type} volume` };
    }
  }

  static async increaseDeviceVolume(
    deviceId: string,
    type: "sink" | "source",
    increment: number = 10,
  ): Promise<AudioOperationResult> {
    try {
      // Get current volume first
      const devices = await this.getAudioDevices();
      const deviceList = type === "sink" ? devices.sinks : devices.sources;
      const device = deviceList.find((d) => d.id === deviceId);

      if (!device) {
        return { success: false, message: `Device ${deviceId} not found` };
      }

      const newVolume = Math.min(100, device.volume + increment);
      return this.setDeviceVolume(deviceId, type, newVolume);
    } catch (error) {
      console.error(`Failed to increase ${type} volume:`, error);
      return { success: false, message: `Failed to increase ${type} volume` };
    }
  }

  static async decreaseDeviceVolume(
    deviceId: string,
    type: "sink" | "source",
    decrement: number = 10,
  ): Promise<AudioOperationResult> {
    try {
      // Get current volume first
      const devices = await this.getAudioDevices();
      const deviceList = type === "sink" ? devices.sinks : devices.sources;
      const device = deviceList.find((d) => d.id === deviceId);

      if (!device) {
        return { success: false, message: `Device ${deviceId} not found` };
      }

      const newVolume = Math.max(0, device.volume - decrement);
      return this.setDeviceVolume(deviceId, type, newVolume);
    } catch (error) {
      console.error(`Failed to decrease ${type} volume:`, error);
      return { success: false, message: `Failed to decrease ${type} volume` };
    }
  }

  static async toggleDeviceMute(
    deviceId: string,
    type: "sink" | "source",
    mute: boolean,
  ): Promise<AudioOperationResult> {
    try {
      const command =
        type === "sink"
          ? LinuxAudioCommands.getSinkMuteCommand(deviceId, mute)
          : LinuxAudioCommands.getSourceMuteCommand(deviceId, mute);

      await execAsync(command);
      return {
        success: true,
        message: `${mute ? "Muted" : "Unmuted"} ${deviceId}`,
      };
    } catch (error) {
      console.error(`Failed to ${mute ? "mute" : "unmute"} ${type}:`, error);
      return {
        success: false,
        message: `Failed to ${mute ? "mute" : "unmute"} ${type}`,
      };
    }
  }

  static async testDevice(deviceId: string): Promise<AudioOperationResult> {
    try {
      // Store current volume to restore later
      const devices = await this.getAudioDevices();
      const device = devices.sinks.find((d) => d.id === deviceId);
      const originalVolume = device?.volume || 50;

      // Try multiple test methods with fallbacks
      try {
        // Method 1: Try speaker-test if available
        await execAsync(
          `timeout 2s speaker-test -t sine -f 1000 -l 1 -s 1 -D ${deviceId}`,
          { timeout: 3000 },
        );
        return { success: true, message: `Test tone played on ${deviceId}` };
      } catch (error1) {
        console.log("speaker-test failed, trying alternative method");

        try {
          // Method 2: Try paplay with a generated tone
          await execAsync(
            `timeout 1s paplay <(ffmpeg -f lavfi -i "sine=frequency=1000:duration=0.5" -f wav -) -d ${deviceId}`,
            { timeout: 2000 },
          );
          return { success: true, message: `Test tone played on ${deviceId}` };
        } catch (error2) {
          console.log("paplay failed, trying volume pulse method");

          // Method 3: Volume pulse test (most compatible)
          await execAsync(LinuxAudioCommands.getSimpleTestCommand(deviceId));
          return {
            success: true,
            message: `Audio test completed for ${deviceId} (volume pulse)`,
          };
        }
      }
    } catch (error) {
      console.error("Failed to test device:", error);
      return { success: false, message: "Failed to test audio device" };
    }
  }

  // Phase 2: Enhanced device information and monitoring

  static async getDeviceHardwareInfo(
    deviceName: string,
    type: "sink" | "source",
  ): Promise<AudioHardwareInfo> {
    try {
      const [hardwareResult, cardResult] = await Promise.all([
        execAsync(
          LinuxAudioCommands.getDeviceHardwareInfoCommand(deviceName, type),
        ),
        execAsync(LinuxAudioCommands.getCardInfoCommand()),
      ]);

      return this.parseHardwareInfo(
        hardwareResult.stdout,
        cardResult.stdout,
        deviceName,
      );
    } catch (error) {
      console.error("Failed to get hardware info:", error);
      return {};
    }
  }

  private static parseHardwareInfo(
    hardwareOutput: string,
    cardOutput: string,
    deviceName: string,
  ): AudioHardwareInfo {
    const info: AudioHardwareInfo = {};

    // Parse sample rate and format
    const sampleMatch = hardwareOutput.match(/Sample Specification:\s*(.+)/);
    if (sampleMatch) {
      const specs = sampleMatch[1];
      const rateMatch = specs.match(/(\d+)\s*Hz/);
      const formatMatch = specs.match(/(s16le|s24le|s32le|f32le)/);
      const channelMatch = specs.match(/(mono|stereo|\d+ch)/);

      if (rateMatch) info.sampleRate = `${rateMatch[1]} Hz`;
      if (formatMatch) info.sampleFormat = formatMatch[1];
      if (channelMatch) info.channels = channelMatch[1];
    }

    // Parse channel map
    const channelMapMatch = hardwareOutput.match(/Channel Map:\s*(.+)/);
    if (channelMapMatch) {
      info.channelMap = channelMapMatch[1].trim();
    }

    // Parse active port
    const activePortMatch = hardwareOutput.match(/Active Port:\s*(.+)/);
    if (activePortMatch) {
      info.activePort = activePortMatch[1].trim();
    }

    // Parse available ports
    const portsSection = hardwareOutput.match(
      /Ports:\s*([\s\S]*?)(?=\n\s*Properties|\n\s*Formats|$)/,
    );
    if (portsSection) {
      const ports = portsSection[1]
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line.includes(":"))
        .map((line) => line.split(":")[0].trim())
        .filter(Boolean);
      info.availablePorts = ports;
    }

    // Determine connection type based on device name and properties
    info.connectionType = this.determineConnectionType(
      deviceName,
      hardwareOutput,
    );

    // Parse driver info
    const driverMatch = hardwareOutput.match(/Driver:\s*(.+)/);
    if (driverMatch) {
      const driver = driverMatch[1].trim();
      if (driver.includes("usb")) info.connectionType = "usb";
      if (driver.includes("bluetooth")) info.connectionType = "bluetooth";
      if (driver.includes("hdmi")) info.connectionType = "hdmi";
    }

    return info;
  }

  private static determineConnectionType(
    deviceName: string,
    properties: string,
  ): "usb" | "bluetooth" | "internal" | "hdmi" | "analog" | "unknown" {
    const name = deviceName.toLowerCase();
    const props = properties.toLowerCase();

    if (name.includes("usb") || props.includes("usb")) return "usb";
    if (name.includes("bluetooth") || props.includes("bluetooth"))
      return "bluetooth";
    if (name.includes("hdmi") || props.includes("hdmi")) return "hdmi";
    if (
      name.includes("analog") ||
      name.includes("built-in") ||
      name.includes("internal")
    )
      return "analog";
    if (name.includes("pci") && !name.includes("usb")) return "internal";

    return "unknown";
  }

  static async getAudioLevels(
    deviceName: string,
    type: "sink" | "source",
  ): Promise<AudioLevelData | null> {
    try {
      const command = LinuxAudioCommands.getAudioLevelCommand(deviceName, type);
      const result = await execAsync(command, { timeout: 2000 });

      // Parse volume from output (simplified approach)
      const volumeMatch = result.stdout.match(/(\d+)%/);
      const level = volumeMatch ? parseInt(volumeMatch[1]) : 0;

      return {
        deviceId: deviceName,
        currentLevel: level,
        peakLevel: Math.min(100, level + Math.random() * 10), // Simulated peak
        timestamp: Date.now(),
      };
    } catch (error) {
      // Silent fail for level monitoring
      return null;
    }
  }

  static async getActiveStreams(): Promise<ActiveAudioStream[]> {
    try {
      const [sinkInputsResult, sourceOutputsResult] = await Promise.all([
        execAsync(LinuxAudioCommands.getActiveSinkInputsCommand()),
        execAsync(LinuxAudioCommands.getActiveSourceOutputsCommand()),
      ]);

      const playbackStreams = this.parseActiveStreams(
        sinkInputsResult.stdout,
        "playback",
      );
      const recordingStreams = this.parseActiveStreams(
        sourceOutputsResult.stdout,
        "recording",
      );

      return [...playbackStreams, ...recordingStreams];
    } catch (error) {
      console.error("Failed to get active streams:", error);
      return [];
    }
  }

  private static parseActiveStreams(
    output: string,
    type: "playback" | "recording",
  ): ActiveAudioStream[] {
    const streams: ActiveAudioStream[] = [];
    const sections = output.split(/Sink Input #|Source Output #/).slice(1);

    sections.forEach((section, index) => {
      const lines = section.split("\n");
      let appName = "Unknown Application";
      let deviceId = "";
      let volume = 100;
      let muted = false;

      // Parse application name
      const appMatch = section.match(/application\.name\s*=\s*"([^"]+)"/);
      if (appMatch) appName = appMatch[1];

      // Parse device
      const deviceMatch = section.match(/(Sink|Source):\s*(.+)/);
      if (deviceMatch) deviceId = deviceMatch[2].trim();

      // Parse volume
      const volumeMatch = section.match(/Volume:\s*[\s\S]*?(\d+)%/);
      if (volumeMatch) volume = parseInt(volumeMatch[1]);

      // Parse mute
      const muteMatch = section.match(/Mute:\s*(yes|no)/);
      if (muteMatch) muted = muteMatch[1] === "yes";

      if (deviceId) {
        streams.push({
          id: `${type}-${index}`,
          applicationName: appName,
          deviceId,
          volume,
          muted,
          type,
        });
      }
    });

    return streams;
  }

  static async getMonitoringData(
    devices: AudioDevice[],
  ): Promise<AudioMonitoringData> {
    try {
      const [levelPromises, activeStreams] = await Promise.all([
        Promise.all(
          devices.map((device) => this.getAudioLevels(device.id, device.type)),
        ),
        this.getActiveStreams(),
      ]);

      const levels: Record<string, AudioLevelData> = {};
      levelPromises.forEach((levelData) => {
        if (levelData) {
          levels[levelData.deviceId] = levelData;
        }
      });

      return {
        levels,
        activeStreams,
        lastUpdate: Date.now(),
      };
    } catch (error) {
      console.error("Failed to get monitoring data:", error);
      return {
        levels: {},
        activeStreams: [],
        lastUpdate: Date.now(),
      };
    }
  }
}
