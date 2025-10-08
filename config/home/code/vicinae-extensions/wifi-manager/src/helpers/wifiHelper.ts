import { WiFiNetwork, WiFiConnectionResult } from "../types/wifi";
import { execAsync, parseTabSeparatedOutput, createSet } from "./commandHelper";
import { getSignalIcon } from "./signalHelper";

export class WiFiHelper {
  static async scanNetworks(): Promise<WiFiNetwork[]> {
    try {
      console.log("Starting WiFi scan...");

      const timeout = 30000; // Increased to 30 seconds
      const scanPromise = execAsync(
        "nmcli -t -f SSID,BSSID,SIGNAL,SECURITY,FREQ dev wifi",
      );
      const knownPromise = execAsync("nmcli -t -f NAME connection show");
      const activePromise = execAsync(
        "nmcli -t -f NAME connection show --active",
      );

      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(
          () => reject(new Error("WiFi scan timed out after 30 seconds")),
          timeout,
        ),
      );

      const [scanResult, knownResult, activeResult] = await Promise.race([
        Promise.all([scanPromise, knownPromise, activePromise]),
        timeoutPromise,
      ]);

      console.log("WiFi scan completed");

      const knownConnections = createSet(knownResult.stdout);
      const activeConnections = createSet(activeResult.stdout);

      const networks: WiFiNetwork[] = [];
      const seenSSIDs = new Set<string>();

      const scanLines = scanResult.stdout.split("\n").filter(Boolean);
      console.log(`Found ${scanLines.length} network entries`);

      parseTabSeparatedOutput(scanResult.stdout).forEach((parts) => {
        const [ssid, bssid, signal, security, frequency] = parts;
        if (!ssid || ssid.trim() === "" || seenSSIDs.has(ssid)) return;

        seenSSIDs.add(ssid);
        networks.push({
          name: ssid,
          id: bssid || `${ssid}-${Date.now()}`,
          ssid,
          bssid: bssid || "",
          signal: parseInt(signal) || 0,
          security: security || "Open",
          known: knownConnections.has(ssid),
          connected: activeConnections.has(ssid),
          frequency: frequency || "2.4 GHz",
        });
      });

      console.log(`Processed ${networks.length} unique networks`);
      return this.sortNetworks(networks);
    } catch (error) {
      console.error("Failed to scan networks:", error);
      return [];
    }
  }

  private static sortNetworks(networks: WiFiNetwork[]): WiFiNetwork[] {
    return networks.sort((a, b) => {
      if (a.connected && !b.connected) return -1;
      if (!a.connected && b.connected) return 1;
      if (a.known && !b.known) return -1;
      if (!a.known && b.known) return 1;
      return (b.signal || 0) - (a.signal || 0);
    });
  }

  static async connectToNetwork(
    ssid: string,
    password?: string,
  ): Promise<WiFiConnectionResult> {
    try {
      try {
        await execAsync(`nmcli connection up "${ssid}"`);
        return { success: true, message: `Connected to ${ssid}` };
      } catch (profileError) {
        console.log("No existing profile, creating new connection");
      }

      if (password) {
        try {
          const { stdout: securityInfo } = await execAsync(
            `nmcli -t -f SSID,SECURITY dev wifi | grep "^${ssid}:"`,
          );
          const security = securityInfo.split(":")[1];

          if (security && security.includes("WPA")) {
            await execAsync(
              `nmcli dev wifi connect "${ssid}" password "${password}" key-mgmt wpa-psk`,
            );
          } else {
            await execAsync(
              `nmcli dev wifi connect "${ssid}" password "${password}"`,
            );
          }
        } catch (securityError) {
          await execAsync(
            `nmcli dev wifi connect "${ssid}" password "${password}"`,
          );
        }
      } else {
        await execAsync(`nmcli dev wifi connect "${ssid}"`);
      }

      return { success: true, message: `Connected to ${ssid}` };
    } catch (error) {
      console.error("Failed to connect:", error);
      return { success: false, message: `Failed to connect to ${ssid}` };
    }
  }

  static async disconnectFromNetwork(
    ssid: string,
  ): Promise<WiFiConnectionResult> {
    try {
      await execAsync(`nmcli connection down "${ssid}"`);
      return { success: true, message: `Disconnected from ${ssid}` };
    } catch (error) {
      console.error("Failed to disconnect:", error);
      return { success: false, message: `Failed to disconnect from ${ssid}` };
    }
  }

  static async forgetNetwork(ssid: string): Promise<WiFiConnectionResult> {
    try {
      await execAsync(`nmcli connection delete "${ssid}"`);
      return { success: true, message: `Forgot ${ssid}` };
    } catch (error) {
      console.error("Failed to forget network:", error);
      return { success: false, message: `Failed to forget ${ssid}` };
    }
  }

  static async rescanNetworks(): Promise<void> {
    try {
      console.log("Starting WiFi rescan...");
      await execAsync("nmcli dev wifi rescan");
      console.log("WiFi rescan completed");
    } catch (error) {
      console.error("Failed to rescan:", error);
    }
  }


  static getSignalIcon(signal?: number): string {
    return getSignalIcon(signal);
  }
}
