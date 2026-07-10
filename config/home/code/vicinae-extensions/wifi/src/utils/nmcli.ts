import { exec } from "child_process";
import { promisify } from "util";
import { readFile } from "fs/promises";
import type { WifiNetwork, SavedNetwork } from "./types";

const execAsync = promisify(exec);

async function run(cmd: string): Promise<string> {
  try {
    const { stdout } = await execAsync(cmd, { timeout: 20000 });
    return stdout;
  } catch (err: any) {
    return err.stdout ?? "";
  }
}

// Split a terse nmcli line on ":" while respecting escaped "\:"
function splitTerse(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  for (let i = 0; i < line.length; i++) {
    if (line[i] === "\\" && i + 1 < line.length && line[i + 1] === ":") {
      current += ":";
      i++;
    } else if (line[i] === ":") {
      fields.push(current);
      current = "";
    } else {
      current += line[i];
    }
  }
  fields.push(current);
  return fields;
}

export async function scanNetworks(rescan = false): Promise<WifiNetwork[]> {
  const flag = rescan ? "yes" : "no";
  const stdout = await run(
    `nmcli -t -f IN-USE,BSSID,SSID,MODE,CHAN,RATE,SIGNAL,SECURITY dev wifi list --rescan ${flag}`
  );
  const bySSID = new Map<string, WifiNetwork>();

  for (const line of stdout.split("\n").filter(Boolean)) {
    const f = splitTerse(line);
    if (f.length < 8) continue;
    const network: WifiNetwork = {
      inUse: f[0] === "*",
      bssid: f[1],
      ssid: f[2],
      mode: f[3],
      channel: parseInt(f[4]) || 0,
      rate: f[5],
      signal: parseInt(f[6]) || 0,
      security: f[7] || "Open",
    };
    const key = network.ssid || network.bssid;
    const existing = bySSID.get(key);
    // Prefer in-use entry, then highest signal
    if (!existing || network.inUse || (!existing.inUse && network.signal > existing.signal)) {
      bySSID.set(key, network);
    }
  }

  return [...bySSID.values()].sort((a, b) => {
    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
    return b.signal - a.signal;
  });
}

export async function getSavedNetworks(): Promise<SavedNetwork[]> {
  const stdout = await run(
    "nmcli -t -f NAME,UUID,TYPE,DEVICE,TIMESTAMP connection show"
  );
  const networks: SavedNetwork[] = [];

  for (const line of stdout.split("\n").filter(Boolean)) {
    const f = splitTerse(line);
    if (f.length < 5 || f[2] !== "802-11-wireless") continue;
    networks.push({
      name: f[0],
      uuid: f[1],
      device: f[3],
      timestamp: parseInt(f[4]) || 0,
    });
  }

  return networks.sort((a, b) => b.timestamp - a.timestamp);
}

export async function getNetworkPassword(name: string): Promise<string | null> {
  const stdout = await run(
    `nmcli -s -t -f 802-11-wireless-security.psk connection show "${name}"`
  );
  const match = stdout.match(/802-11-wireless-security\.psk:(.+)/);
  return match ? match[1].trim() : null;
}

export async function connectToNetwork(
  ssid: string,
  password: string
): Promise<{ success: boolean; error?: string }> {
  const stdout = await run(
    `nmcli device wifi connect "${ssid}" password "${password}"`
  );
  return stdout.toLowerCase().includes("error")
    ? { success: false, error: stdout.trim() }
    : { success: true };
}

export async function connectSaved(
  name: string
): Promise<{ success: boolean; error?: string }> {
  const stdout = await run(`nmcli connection up "${name}"`);
  return stdout.toLowerCase().includes("error")
    ? { success: false, error: stdout.trim() }
    : { success: true };
}

export async function disconnectWifi(): Promise<void> {
  const stdout = await run("nmcli -t -f DEVICE,TYPE device status");
  for (const line of stdout.split("\n").filter(Boolean)) {
    const f = splitTerse(line);
    if (f[1] === "wifi") {
      await run(`nmcli device disconnect "${f[0]}"`);
      return;
    }
  }
}

export async function forgetNetwork(uuid: string): Promise<void> {
  await run(`nmcli connection delete "${uuid}"`);
}

export async function setWifi(on: boolean): Promise<void> {
  await run(`nmcli radio wifi ${on ? "on" : "off"}`);
}

export interface WifiConnectionInfo {
  ip: string | null;
  device: string | null;
}

export async function getWifiConnectionInfo(): Promise<WifiConnectionInfo> {
  const stdout = await run("nmcli -t -f DEVICE,TYPE,STATE dev status");
  for (const line of stdout.split("\n").filter(Boolean)) {
    const f = splitTerse(line);
    if (f[1] === "wifi" && f[2] === "connected") {
      const ipOut = await run(`nmcli -g IP4.ADDRESS dev show "${f[0]}"`);
      const ip = ipOut.trim().split("\n")[0].replace(/\/\d+$/, "");
      return { ip: ip || null, device: f[0] };
    }
  }
  return { ip: null, device: null };
}

export async function getDeviceBytes(device: string): Promise<{ rx: number; tx: number }> {
  const content = await readFile("/proc/net/dev", "utf8");
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (trimmed.startsWith(device + ":")) {
      const parts = trimmed.replace(device + ":", "").trim().split(/\s+/);
      return { rx: parseInt(parts[0]) || 0, tx: parseInt(parts[8]) || 0 };
    }
  }
  return { rx: 0, tx: 0 };
}

export async function getPing(host = "8.8.8.8"): Promise<number | null> {
  const stdout = await run(`ping -c 1 -W 1 ${host}`);
  const match = stdout.match(/time=(\d+\.?\d*)\s*ms/);
  return match ? parseFloat(match[1]) : null;
}
