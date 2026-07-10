import { useCallback, useEffect, useState } from "react";
import {
  Action,
  ActionPanel,
  Color,
  confirmAlert,
  Icon,
  List,
  showToast,
  Toast,
  useNavigation,
} from "@vicinae/api";
import ShareView from "./components/ShareView";
import { connectSaved, disconnectWifi, forgetNetwork, getSavedNetworks } from "./utils/nmcli";
import type { SavedNetwork } from "./utils/types";

export default function Saved() {
  const { push } = useNavigation();
  const [networks, setNetworks] = useState<SavedNetwork[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeDevice, setActiveDevice] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    const nets = await getSavedNetworks();
    setNetworks(nets);
    const connected = nets.find((n) => n.device && n.device !== "--");
    setActiveDevice(connected?.name ?? null);
    setLoading(false);
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  const handleConnect = async (network: SavedNetwork) => {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Connecting to ${network.name}…` });
    const result = await connectSaved(network.name);
    toast.style = result.success ? Toast.Style.Success : Toast.Style.Failure;
    toast.title = result.success ? "Connected" : "Connection failed";
    toast.message = result.success ? network.name : result.error;
    if (result.success) refresh();
  };

  const handleDisconnect = async () => {
    const toast = await showToast({ style: Toast.Style.Animated, title: "Disconnecting…" });
    await disconnectWifi();
    toast.style = Toast.Style.Success;
    toast.title = "Disconnected";
    refresh();
  };

  const handleForget = async (network: SavedNetwork) => {
    const confirmed = await confirmAlert({
      title: `Forget "${network.name}"?`,
      message: "This will remove the saved connection.",
      primaryAction: { title: "Forget" },
    });
    if (!confirmed) return;
    const toast = await showToast({ style: Toast.Style.Animated, title: `Forgetting ${network.name}…` });
    await forgetNetwork(network.uuid);
    toast.style = Toast.Style.Success;
    toast.title = "Forgotten";
    refresh();
  };

  const isConnected = (n: SavedNetwork) => n.name === activeDevice;

  return (
    <List
      isLoading={loading}
      isShowingDetail
      searchBarPlaceholder="Search saved networks…"
    >
      {networks.map((n) => {
        const connected = isConnected(n);
        return (
          <List.Item
            key={n.uuid}
            title={n.name}
            icon={{
              source: connected ? Icon.CheckCircle : Icon.Wifi,
              tintColor: connected ? Color.Green : Color.SecondaryText,
            }}
            accessories={connected ? [{ tag: { value: "Connected", color: Color.Green } }] : []}
            detail={
              <List.Item.Detail
                metadata={
                  <List.Item.Detail.Metadata>
                    <List.Item.Detail.Metadata.Label
                      title="Status"
                      text={connected ? "Connected" : "Saved"}
                      icon={{
                        source: connected ? Icon.CheckCircle : Icon.Circle,
                        tintColor: connected ? Color.Green : Color.SecondaryText,
                      }}
                    />
                    <List.Item.Detail.Metadata.Label
                      title="Device"
                      text={n.device && n.device !== "--" ? n.device : "Not active"}
                    />
                    <List.Item.Detail.Metadata.Separator />
                    <List.Item.Detail.Metadata.Label title="UUID" text={n.uuid} />
                  </List.Item.Detail.Metadata>
                }
              />
            }
            actions={
              <ActionPanel>
                {connected ? (
                  <Action
                    title="Disconnect"
                    icon={Icon.XMarkCircle}
                    style="destructive"
                    onAction={handleDisconnect}
                  />
                ) : (
                  <Action
                    title="Connect"
                    icon={Icon.Wifi}
                    onAction={() => handleConnect(n)}
                  />
                )}
                <Action
                  title="Share Network"
                  icon={Icon.BarCode}
                  shortcut={{ modifiers: ["ctrl"], key: "s" }}
                  onAction={() => push(<ShareView ssid={n.name} security="WPA" />)}
                />
                <Action.CopyToClipboard
                  title="Copy Network Name"
                  content={n.name}
                  shortcut={{ modifiers: ["ctrl"], key: "c" }}
                />
                <Action
                  title="Forget Network"
                  icon={Icon.Trash}
                  style="destructive"
                  shortcut={{ modifiers: ["ctrl"], key: "delete" }}
                  onAction={() => handleForget(n)}
                />
                <Action
                  title="Refresh"
                  icon={Icon.ArrowClockwise}
                  shortcut={{ modifiers: ["ctrl"], key: "r" }}
                  onAction={refresh}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
