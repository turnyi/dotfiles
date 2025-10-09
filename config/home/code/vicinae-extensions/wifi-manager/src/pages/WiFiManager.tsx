import React, { useState } from "react";
import { Icon, confirmAlert, Keyboard } from "@vicinae/api";
import { useWifi } from "../hooks/useWifi";
import { WiFiNetwork } from "../types/wifi";
import { WiFiHelper } from "../helpers/wifiHelper";
import { NetworkList } from "../components/NetworkList";
import { ConnectionForm } from "../components/ConnectionForm";
import { NetworkIcons, ActionIcons } from "../helpers/icons";

interface WiFiManagerProps {
  onBack: () => void;
}

export function WiFiManager({ onBack }: WiFiManagerProps) {
  const {
    knownNetworks,
    unknownNetworks,
    loading,
    connect,
    disconnect,
    forget,
    rescan,
  } = useWifi();
  const [showConnectForm, setShowConnectForm] = useState<WiFiNetwork | null>(
    null,
  );

  const handleConnectWithCheck = (network: WiFiNetwork) => {
    if (network.id === "empty") return;

    if (network.known) {
      connect(network.ssid);
    } else {
      if (network.security === "Open") {
        connect(network.ssid);
      } else {
        setShowConnectForm(network);
      }
    }
  };

  const handleForget = async (ssid: string) => {
    const confirmed = await confirmAlert({
      title: "Forget Network",
      message: `Are you sure you want to forget "${ssid}"?`,
      primaryAction: { title: "Forget" },
    });

    if (confirmed) {
      forget(ssid);
    }
  };

  const getNetworkIcon = (network: WiFiNetwork) => {
    if (network.id === "empty") return NetworkIcons.Wifi;
    if (network.connected) return NetworkIcons.Connected;
    if (network.known) return NetworkIcons.Known;
    if (network.security === "Open") return NetworkIcons.Globe;
    return NetworkIcons.Lock;
  };

  const getSubtitle = (network: WiFiNetwork) => {
    if (network.id === "empty") return "Press Ctrl+R to scan for networks";
    return `${WiFiHelper.getSignalIcon(network.signal)} ${network.signal}%`;
  };

  const getAccessories = (network: WiFiNetwork) => {
    if (network.id === "empty") {
      return [{ text: "⌃R Scan" }];
    }

    const accessories = [{ text: WiFiHelper.getSignalIcon(network.signal) }];

    if (network.connected) {
      accessories.push({ tag: { value: "Connected", color: "#00ff00" } });
    }

    const actionHint = network.connected
      ? "⏎ Disconnect"
      : network.known
        ? "⏎ Connect"
        : network.security === "Open"
          ? "⏎ Connect"
          : "⏎ Enter Password";

    accessories.push({
      text: actionHint,
      tooltip: "Press Enter to perform this action",
    });

    return accessories;
  };

  const getActions = (network: WiFiNetwork) => {
    const actions = [];

    if (network.id === "empty") {
      actions.push({
        title: "Rescan Networks",
        icon: Icon.ArrowClockwise,
        onAction: rescan,
        shortcut: { key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut,
      });
    } else {
      if (network.connected) {
        actions.push({
          title: "Disconnect",
          icon: Icon.XMarkCircle,
          onAction: () => disconnect(network.ssid),
        });
      } else {
        actions.push({
          title: "Connect",
          icon: Icon.Wifi,
          onAction: () => handleConnectWithCheck(network),
        });
      }

      if (network.known) {
        actions.push({
          title: "Forget Network",
          icon: Icon.Trash,
          onAction: () => handleForget(network.ssid),
          style: "destructive" as const,
        });
      }
    }

    actions.push({
      title: "Back to Menu",
      icon: Icon.ArrowLeft,
      onAction: onBack,
    });

    return actions;
  };

  if (showConnectForm) {
    return (
      <ConnectionForm
        title="Password"
        placeholder="Enter WiFi password"
        isPassword={true}
        networkName={showConnectForm.ssid}
        signal={showConnectForm.signal}
        onConnect={(password) => {
          connect(showConnectForm.ssid, password);
          setShowConnectForm(null);
        }}
        onCancel={() => setShowConnectForm(null)}
      />
    );
  }

  const sections = [];

  if (knownNetworks.length > 0) {
    sections.push({ title: "Known Networks", items: knownNetworks });
  }

  if (unknownNetworks.length > 0) {
    sections.push({ title: "Available Networks", items: unknownNetworks });
  }

  if (sections.length === 0 && !loading) {
    sections.push({
      title: "No networks found",
      items: [
        {
          name: "No WiFi networks found",
          id: "empty",
          ssid: "",
          bssid: "",
          signal: 0,
          security: "",
          known: false,
          connected: false,
          frequency: "",
        },
      ],
    });
  }

  return (
    <NetworkList
      items={[...knownNetworks, ...unknownNetworks]}
      loading={loading}
      searchPlaceholder="Search WiFi networks..."
      getIcon={getNetworkIcon}
      getSubtitle={getSubtitle}
      getAccessories={getAccessories}
      getActions={getActions}
      sections={sections}
      globalActions={[
        {
          title: "Rescan Networks",
          icon: Icon.ArrowClockwise,
          onAction: rescan,
          shortcut: { key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut,
        },
      ]}
    />
  );
}
