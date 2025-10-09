import React from "react";
import { Icon, confirmAlert, Keyboard } from "@vicinae/api";
import { useBluetooth } from "../hooks/useBluetooth";
import { BluetoothDevice } from "../types/bluetooth";
import { BluetoothHelper } from "../helpers/bluetoothHelper";
import { NetworkList } from "../components/NetworkList";
import {
  BluetoothIcons,
  BatteryIcons,
  ActionIcons,
  getBatteryIcon,
  getBluetoothDeviceIcon,
} from "../helpers/icons";

interface BluetoothManagerProps {
  onBack: () => void;
}

export function BluetoothManager({ onBack }: BluetoothManagerProps) {
  const {
    pairedDevices,
    availableDevices,
    loading,
    scanning,
    connect,
    disconnect,
    pair,
    unpair,
    startScan,
  } = useBluetooth();

  const handleConnectWithCheck = (device: BluetoothDevice) => {
    if (device.id === "empty") return;

    if (device.connected) {
      disconnect(device.address);
    } else if (device.paired) {
      connect(device.address);
    } else {
      pair(device.address);
    }
  };

  const handleUnpair = async (device: BluetoothDevice) => {
    if (device.id === "empty") return;

    const confirmed = await confirmAlert({
      title: "Unpair Device",
      message: `Are you sure you want to unpair "${device.name}"?`,
      primaryAction: { title: "Unpair" },
    });

    if (confirmed) {
      unpair(device.address);
    }
  };

  const getDeviceIcon = (device: BluetoothDevice) => {
    if (device.id === "empty") return BluetoothIcons.Bluetooth;
    if (device.connected) return BluetoothIcons.Connected;
    return getBluetoothDeviceIcon(device.deviceType);
  };

  const getSubtitle = (device: BluetoothDevice) => {
    if (device.id === "empty") return "Press Ctrl+R to scan for devices";

    const parts = [device.address];
    if (device.battery !== undefined) {
      parts.push(`${getBatteryIcon(device.battery)} ${device.battery}%`);
    }
    parts.push(device.deviceType);
    return parts.join(" • ");
  };

  const getAccessories = (device: BluetoothDevice) => {
    if (device.id === "empty") {
      return [{ text: "⌃R Scan" }];
    }

    const accessories = [{ text: BluetoothHelper.getDeviceIcon(device) }];

    if (device.connected) {
      accessories.push({ tag: { value: "Connected", color: "#00ff00" } });
    } else if (device.paired) {
      accessories.push({ tag: { value: "Paired", color: "#0066ff" } });
    }

    const actionHint = device.connected
      ? "⏎ Disconnect"
      : device.paired
        ? "⏎ Connect"
        : "⏎ Pair";

    accessories.push({
      text: actionHint,
      tooltip: "Press Enter to perform this action",
    });

    return accessories;
  };

  const getActions = (device: BluetoothDevice) => {
    const actions = [];

    if (device.id === "empty") {
      actions.push({
        title: "Scan for Devices",
        icon: Icon.ArrowClockwise,
        onAction: startScan,
        shortcut: { key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut,
      });
      return actions;
    }

    if (device.connected) {
      actions.push({
        title: "Disconnect",
        icon: Icon.XMarkCircle,
        onAction: () => disconnect(device.address),
      });
    } else if (device.paired) {
      actions.push({
        title: "Connect",
        icon: "🔵",
        onAction: () => connect(device.address),
      });
    } else {
      actions.push({
        title: "Pair",
        icon: "🔗",
        onAction: () => pair(device.address),
      });
    }

    if (device.paired) {
      actions.push({
        title: "Unpair Device",
        icon: Icon.Trash,
        onAction: () => handleUnpair(device),
        style: "destructive" as const,
      });
    }

    actions.push({
      title: "Back to Menu",
      icon: Icon.ArrowLeft,
      onAction: onBack,
    });

    return actions;
  };

  const connectedDevices = pairedDevices.filter((d) => d.connected);
  const pairedNotConnected = pairedDevices.filter((d) => !d.connected);
  const unpaired = availableDevices.filter((d) => !d.paired);

  const sections = [];

  if (connectedDevices.length > 0) {
    sections.push({ title: "Connected Devices", items: connectedDevices });
  }

  if (pairedNotConnected.length > 0) {
    sections.push({ title: "Paired Devices", items: pairedNotConnected });
  }

  if (unpaired.length > 0) {
    sections.push({ title: "Available Devices", items: unpaired });
  }

  if (sections.length === 0 && !loading) {
    sections.push({
      title: "No devices found",
      items: [
        {
          name: scanning
            ? "Scanning for devices..."
            : "No Bluetooth devices found",
          id: "empty",
          address: "",
          connected: false,
          known: false,
          paired: false,
          trusted: false,
          deviceType: "unknown" as const,
        },
      ],
    });
  }

  return (
    <NetworkList
      items={[...connectedDevices, ...pairedNotConnected, ...unpaired]}
      loading={loading}
      searchPlaceholder="Search Bluetooth devices..."
      getIcon={getDeviceIcon}
      getSubtitle={getSubtitle}
      getAccessories={getAccessories}
      getActions={getActions}
      sections={sections}
      globalActions={[
        {
          title: scanning ? "Scanning..." : "Scan for Devices",
          icon: Icon.ArrowClockwise,
          onAction: startScan,
          shortcut: { key: "r", modifiers: ["cmd"] } as Keyboard.Shortcut,
        },
      ]}
    />
  );
}
