import { useCallback, useEffect, useRef, useState } from "react";
import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  showToast,
  Toast,
  useNavigation,
} from "@vicinae/api";
import ConnectForm from "./components/ConnectForm";
import ShareView from "./components/ShareView";
import {
  connectSaved,
  disconnectWifi,
  getDeviceBytes,
  getPing,
  getWifiConnectionInfo,
  scanNetworks,
} from "./utils/nmcli";
import { frequencyBand, isOpen, signalBars, signalColor, signalIcon, signalLabel } from "./utils/helpers";
import type { WifiNetwork } from "./utils/types";

const LOADING_MESSAGES = [
  "Scanning the airwaves…",
  "Negotiating radio frequencies…",
  "Whispering to access points…",
  "Triangulating signal sources…",
  "Listening for beacons…",
  "Polling the ether…",
];

interface NetStats {
  ping: number | null;
  rx: number;
  tx: number;
}

function formatSpeed(bps: number): string {
  if (bps >= 1024 * 1024) return `${(bps / (1024 * 1024)).toFixed(1)} MB/s`;
  if (bps >= 1024) return `${(bps / 1024).toFixed(0)} KB/s`;
  return `${Math.round(bps)} B/s`;
}

export default function Scan() {
  const { push } = useNavigation();
  const [networks, setNetworks] = useState<WifiNetwork[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ip, setIp] = useState<string | null>(null);
  const [wifiDevice, setWifiDevice] = useState<string | null>(null);
  const [netStats, setNetStats] = useState<NetStats | null>(null);
  const [showHidden, setShowHidden] = useState(false);
  const [loadingMsg, setLoadingMsg] = useState(LOADING_MESSAGES[0]);
  const lastBytesRef = useRef<{ rx: number; tx: number; ts: number } | null>(null);

  useEffect(() => {
    if (!loading || networks.length > 0) return;
    let i = 0;
    const id = setInterval(() => {
      i = (i + 1) % LOADING_MESSAGES.length;
      setLoadingMsg(LOADING_MESSAGES[i]);
    }, 1800);
    return () => clearInterval(id);
  }, [loading, networks.length]);

  // Live bandwidth + ping polling
  useEffect(() => {
    if (!wifiDevice) {
      setNetStats(null);
      lastBytesRef.current = null;
      return;
    }
    let active = true;

    const sampleBytes = async () => {
      if (!active) return;
      const bytes = await getDeviceBytes(wifiDevice);
      const now = Date.now();
      if (lastBytesRef.current && active) {
        const dt = (now - lastBytesRef.current.ts) / 1000;
        const rx = Math.max(0, (bytes.rx - lastBytesRef.current.rx) / dt);
        const tx = Math.max(0, (bytes.tx - lastBytesRef.current.tx) / dt);
        setNetStats((prev) => ({ ping: prev?.ping ?? null, rx, tx }));
      }
      lastBytesRef.current = { rx: bytes.rx, tx: bytes.tx, ts: now };
    };

    const samplePing = async () => {
      if (!active) return;
      const ping = await getPing();
      if (active) setNetStats((prev) => (prev ? { ...prev, ping } : { ping, rx: 0, tx: 0 }));
    };

    sampleBytes();
    samplePing();
    const bytesId = setInterval(sampleBytes, 2000);
    const pingId = setInterval(samplePing, 5000);
    return () => {
      active = false;
      clearInterval(bytesId);
      clearInterval(pingId);
    };
  }, [wifiDevice]);

  const refresh = useCallback(async (rescan = false) => {
    setLoading(true);
    setError(null);
    try {
      const [cached, connInfo] = await Promise.all([scanNetworks(false), getWifiConnectionInfo()]);
      setNetworks(cached);
      setIp(connInfo.ip);
      setWifiDevice(connInfo.device);
      setLoading(false);
      if (rescan || cached.length === 0) {
        const fresh = await scanNetworks(true);
        setNetworks(fresh);
      }
    } catch {
      setError("Scan failed. Make sure WiFi is enabled.");
      setLoading(false);
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  const handleConnect = async (network: WifiNetwork) => {
    if (!isOpen(network.security)) {
      push(
        <ConnectForm
          ssid={network.ssid}
          signal={network.signal}
          security={network.security}
          channel={network.channel}
          onConnected={refresh}
        />
      );
      return;
    }
    const toast = await showToast({ style: Toast.Style.Animated, title: `Connecting to ${network.ssid}…` });
    const result = await connectSaved(network.ssid);
    toast.style = result.success ? Toast.Style.Success : Toast.Style.Failure;
    toast.title = result.success ? "Connected" : "Connection failed";
    if (result.success) refresh();
  };

  const handleDisconnect = async () => {
    const toast = await showToast({ style: Toast.Style.Animated, title: "Disconnecting…" });
    await disconnectWifi();
    toast.style = Toast.Style.Success;
    toast.title = "Disconnected";
    refresh();
  };

  if (error) {
    return (
      <List>
        <List.EmptyView
          icon={{ source: Icon.WifiDisabled, tintColor: Color.Red }}
          title="Scan Failed"
          description={error}
          actions={
            <ActionPanel>
              <Action title="Retry" icon={Icon.ArrowClockwise} onAction={refresh} />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  const connected = networks.filter((n) => n.inUse);
  const visible = networks.filter((n) => !n.inUse && n.ssid);
  const hidden = networks.filter((n) => !n.inUse && !n.ssid);

  const renderNetwork = (n: WifiNetwork) => {
    const band = frequencyBand(n.channel) || `Ch. ${n.channel}`;
    const statsLine =
      n.inUse && netStats
        ? `\n\n↓ **${formatSpeed(netStats.rx)}**  ·  ↑ **${formatSpeed(netStats.tx)}**${
            netStats.ping !== null ? `  ·  ping **${Math.round(netStats.ping)} ms**` : ""
          }`
        : "";

    return (
      <List.Item
        key={`${n.bssid}-${n.ssid}`}
        title={n.ssid || n.bssid}
        icon={{
          source: n.inUse ? Icon.CheckCircle : signalIcon(n.signal),
          tintColor: n.inUse ? Color.Green : signalColor(n.signal),
        }}
        accessories={[
          { text: `${n.signal}%`, tooltip: "Signal strength" },
          { text: band, tooltip: `Channel ${n.channel}` },
          { icon: isOpen(n.security) ? Icon.LockUnlocked : Icon.Lock, tooltip: n.security },
        ]}
        detail={
          <List.Item.Detail
            markdown={`\`${signalBars(n.signal)}\`  **${n.signal}%**\n\n${signalLabel(n.signal)} · ${band}\n\nRate: ${n.rate}${statsLine}`}
            metadata={
              <List.Item.Detail.Metadata>
                {n.inUse && (
                  <>
                    <List.Item.Detail.Metadata.Label
                      title="Status"
                      text="Connected"
                      icon={{ source: Icon.CheckCircle, tintColor: Color.Green }}
                    />
                    {ip && <List.Item.Detail.Metadata.Label title="IP Address" text={ip} />}
                    <List.Item.Detail.Metadata.Separator />
                  </>
                )}
                <List.Item.Detail.Metadata.Label title="Security" text={n.security} />
                <List.Item.Detail.Metadata.Label title="Channel" text={`${n.channel}`} />
                <List.Item.Detail.Metadata.Label title="Mode" text={n.mode} />
                <List.Item.Detail.Metadata.Separator />
                <List.Item.Detail.Metadata.Label title="BSSID" text={n.bssid} />
              </List.Item.Detail.Metadata>
            }
          />
        }
        actions={
          <ActionPanel>
            {n.inUse ? (
              <Action
                title="Disconnect"
                icon={Icon.XMarkCircle}
                style="destructive"
                onAction={handleDisconnect}
              />
            ) : (
              <Action title="Connect" icon={Icon.Wifi} onAction={() => handleConnect(n)} />
            )}
            {n.inUse && ip && (
              <Action.CopyToClipboard
                title="Copy IP Address"
                content={ip}
                shortcut={{ modifiers: ["ctrl", "shift"], key: "i" }}
              />
            )}
            <Action
              title="Share Network"
              icon={Icon.BarCode}
              shortcut={{ modifiers: ["ctrl"], key: "s" }}
              onAction={() => push(<ShareView ssid={n.ssid} security={n.security} signal={n.signal} channel={n.channel} />)}
            />
            <Action.CopyToClipboard
              title="Copy SSID"
              content={n.ssid}
              shortcut={{ modifiers: ["ctrl"], key: "c" }}
            />
            <Action
              title="Rescan Networks"
              icon={Icon.ArrowClockwise}
              shortcut={{ modifiers: ["ctrl"], key: "r" }}
              onAction={() => refresh(true)}
            />
            {hidden.length > 0 && (
              <Action
                title={showHidden ? "Hide Hidden Networks" : `Show ${hidden.length} Hidden Network${hidden.length !== 1 ? "s" : ""}`}
                icon={showHidden ? Icon.EyeSlash : Icon.Eye}
                shortcut={{ modifiers: ["ctrl"], key: "h" }}
                onAction={() => setShowHidden((v) => !v)}
              />
            )}
          </ActionPanel>
        }
      />
    );
  };

  return (
    <List isLoading={loading} isShowingDetail searchBarPlaceholder="Search networks…">
      <List.EmptyView icon={Icon.Wifi} title={loadingMsg} />
      {connected.length > 0 && (
        <List.Section title="Connected">{connected.map(renderNetwork)}</List.Section>
      )}
      <List.Section title="Available Networks">{visible.map(renderNetwork)}</List.Section>
      {showHidden && hidden.length > 0 && (
        <List.Section title="Hidden Networks">{hidden.map(renderNetwork)}</List.Section>
      )}
      {!showHidden && hidden.length > 0 && (
        <List.Section title="">
          <List.Item
            title={`${hidden.length} hidden network${hidden.length !== 1 ? "s" : ""}`}
            subtitle="Press Ctrl+H to reveal"
            icon={{ source: Icon.Eye, tintColor: Color.SecondaryText }}
            actions={
              <ActionPanel>
                <Action title="Show Hidden Networks" icon={Icon.Eye} onAction={() => setShowHidden(true)} />
                <Action
                  title="Rescan Networks"
                  icon={Icon.ArrowClockwise}
                  shortcut={{ modifiers: ["ctrl"], key: "r" }}
                  onAction={() => refresh(true)}
                />
              </ActionPanel>
            }
          />
        </List.Section>
      )}
    </List>
  );
}
