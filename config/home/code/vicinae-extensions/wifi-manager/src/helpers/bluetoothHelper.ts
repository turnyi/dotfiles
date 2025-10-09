import { BluetoothDevice, BluetoothConnectionResult } from "../types/bluetooth";
import { execAsync } from "./commandHelper";

export class BluetoothHelper {
  static async scanDevices(): Promise<BluetoothDevice[]> {
    try {
      await execAsync("bluetoothctl power on", { timeout: 3000 });

      const { stdout: devicesOutput } = await execAsync(
        "bluetoothctl devices",
        { timeout: 5000 },
      );
      const { stdout: pairedOutput } = await execAsync(
        "bluetoothctl devices Paired",
        { timeout: 3000 },
      ).catch(() => ({ stdout: "" }));
      const { stdout: connectedOutput } = await execAsync(
        "bluetoothctl devices Connected",
        { timeout: 3000 },
      ).catch(() => ({ stdout: "" }));

      const pairedAddresses = new Set(
        pairedOutput
          .split("\n")
          .filter(Boolean)
          .map((line) => line.split(" ")[1])
          .filter(Boolean),
      );

      const connectedAddresses = new Set(
        connectedOutput
          .split("\n")
          .filter(Boolean)
          .map((line) => line.split(" ")[1])
          .filter(Boolean),
      );

      const devices: BluetoothDevice[] = [];
      const seenAddresses = new Set<string>();

      const deviceLines = devicesOutput.split("\n").filter(Boolean);

      for (const line of deviceLines) {
        const parts = line.split(" ");
        if (parts.length < 3 || parts[0] !== "Device") continue;

        const address = parts[1];
        const name = parts.slice(2).join(" ");

        if (!address || seenAddresses.has(address)) continue;
        seenAddresses.add(address);

        const isPaired = pairedAddresses.has(address);
        const isConnected = connectedAddresses.has(address);

        const battery = isConnected
          ? await this.getBatteryLevel(address)
          : undefined;

        devices.push({
          name: name || address,
          id: address,
          address,
          connected: isConnected,
          known: isPaired,
          paired: isPaired,
          trusted: false,
          deviceType: this.guessDeviceType(name),
          battery,
        });
      }

      return this.sortDevices(devices);
    } catch (error) {
      console.error("Failed to scan Bluetooth devices:", error);
      return [];
    }
  }

  private static guessDeviceType(name: string): BluetoothDevice["deviceType"] {
    if (!name) return "unknown";
    const lowerName = name.toLowerCase();

    if (
      lowerName.includes("headphone") ||
      lowerName.includes("headset") ||
      lowerName.includes("speaker") ||
      lowerName.includes("airpods") ||
      lowerName.includes("buds") ||
      lowerName.includes("earbud") ||
      lowerName.includes("beats") ||
      lowerName.includes("audio") ||
      lowerName.includes("soundcore") ||
      lowerName.includes("sony") ||
      lowerName.includes("bose") ||
      lowerName.includes("jbl") ||
      lowerName.includes("sennheiser")
    ) {
      return "audio";
    }

    if (
      lowerName.includes("mouse") ||
      lowerName.includes("keyboard") ||
      lowerName.includes("trackpad") ||
      lowerName.includes("magic mouse") ||
      lowerName.includes("magic keyboard") ||
      lowerName.includes("logitech")
    ) {
      return "input";
    }

    if (
      lowerName.includes("phone") ||
      lowerName.includes("iphone") ||
      lowerName.includes("android") ||
      lowerName.includes("samsung") ||
      lowerName.includes("pixel") ||
      lowerName.includes("oneplus")
    ) {
      return "phone";
    }

    if (
      lowerName.includes("laptop") ||
      lowerName.includes("pc") ||
      lowerName.includes("macbook") ||
      lowerName.includes("computer") ||
      lowerName.includes("desktop") ||
      lowerName.includes("imac")
    ) {
      return "computer";
    }

    return "unknown";
  }

  private static sortDevices(devices: BluetoothDevice[]): BluetoothDevice[] {
    return devices.sort((a, b) => {
      if (a.connected && !b.connected) return -1;
      if (!a.connected && b.connected) return 1;
      if (a.paired && !b.paired) return -1;
      if (!a.paired && b.paired) return 1;
      return a.name.localeCompare(b.name);
    });
  }

  static async connectToDevice(
    address: string,
  ): Promise<BluetoothConnectionResult> {
    if (!address || address.trim() === "") {
      return { success: false, message: "Invalid device address" };
    }

    try {
      await execAsync(`bluetoothctl connect ${address}`, { timeout: 10000 });
      return { success: true, message: `Connected to device` };
    } catch (error: any) {
      console.error("Failed to connect:", error);
      const errorMsg = error.stderr || error.stdout || error.message || "";
      if (errorMsg.includes("Device or resource busy")) {
        return { success: false, message: "Device is busy, try again" };
      }
      if (errorMsg.includes("Connection refused")) {
        return { success: false, message: "Device refused connection" };
      }
      return { success: false, message: `Failed to connect to device` };
    }
  }

  static async disconnectFromDevice(
    address: string,
  ): Promise<BluetoothConnectionResult> {
    if (!address || address.trim() === "") {
      return { success: false, message: "Invalid device address" };
    }

    try {
      await execAsync(`bluetoothctl disconnect ${address}`, { timeout: 5000 });
      return { success: true, message: `Disconnected from device` };
    } catch (error) {
      console.error("Failed to disconnect:", error);
      return { success: false, message: `Failed to disconnect from device` };
    }
  }

  static async pairDevice(address: string): Promise<BluetoothConnectionResult> {
    if (!address || address.trim() === "") {
      return { success: false, message: "Invalid device address" };
    }

    try {
      const result = await execAsync(`bluetoothctl pair ${address}`, {
        timeout: 15000,
      });
      return { success: true, message: `Paired with device` };
    } catch (error: any) {
      console.error("Failed to pair:", error);
      const errorMsg = error.stderr || error.stdout || error.message || "";

      if (
        errorMsg.includes("AlreadyExists") ||
        errorMsg.includes("Already paired")
      ) {
        return { success: true, message: "Device already paired" };
      }
      if (errorMsg.includes("AuthenticationFailed")) {
        return {
          success: false,
          message: "Pairing failed - check device is in pairing mode",
        };
      }
      if (errorMsg.includes("ConnectionAttemptFailed")) {
        return {
          success: false,
          message: "Cannot reach device - check it's discoverable",
        };
      }

      return { success: false, message: `Failed to pair with device` };
    }
  }

  static async unpairDevice(
    address: string,
  ): Promise<BluetoothConnectionResult> {
    if (!address || address.trim() === "") {
      return { success: false, message: "Invalid device address" };
    }

    try {
      await execAsync(`bluetoothctl remove ${address}`, { timeout: 5000 });
      return { success: true, message: `Unpaired device` };
    } catch (error) {
      console.error("Failed to unpair:", error);
      return { success: false, message: `Failed to unpair device` };
    }
  }

  static async startScan(): Promise<void> {
    try {
      await execAsync("bluetoothctl power on", { timeout: 3000 });
      await execAsync("bluetoothctl scan on", { timeout: 3000 });
    } catch (error) {
      console.error("Failed to start scan:", error);
    }
  }

  static async stopScan(): Promise<void> {
    try {
      await execAsync("bluetoothctl scan off", { timeout: 3000 });
    } catch (error) {
      console.error("Failed to stop scan:", error);
    }
  }

  private static async getBatteryLevel(
    address: string,
  ): Promise<number | undefined> {
    try {
      const { stdout } = await execAsync(`bluetoothctl info ${address}`, {
        timeout: 3000,
      });
      const batteryMatch = stdout.match(
        /Battery Percentage: \(0x[0-9a-f]+\)\s+(\d+)/i,
      );
      if (batteryMatch) {
        return parseInt(batteryMatch[1]);
      }
    } catch (error) {
      // Battery info not available for this device
    }
    return undefined;
  }

  static getDeviceIcon(device: BluetoothDevice): string {
    switch (device.deviceType) {
      case "audio":
        return "🎧";
      case "input":
        return "⌨️";
      case "phone":
        return "📱";
      case "computer":
        return "💻";
      default:
        return "📡";
    }
  }
}
