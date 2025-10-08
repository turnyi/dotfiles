import React, { useState } from "react";
import { List, ActionPanel, Action } from "@vicinae/api";
import { WiFiManager } from "./pages/WiFiManager";
import { BluetoothManager } from "./pages/BluetoothManager";

type ManagerType = "wifi" | "bluetooth" | null;

export default function NetworkManager() {
  const [selectedManager, setSelectedManager] = useState<ManagerType>(null);

  if (selectedManager === "wifi") {
    return <WiFiManager onBack={() => setSelectedManager(null)} />;
  }

  if (selectedManager === "bluetooth") {
    return <BluetoothManager onBack={() => setSelectedManager(null)} />;
  }

  return (
    <List searchBarPlaceholder="Choose network manager...">
      <List.Section title="Network Managers">
        <List.Item
          title="WiFi Manager"
          subtitle="Manage WiFi connections and networks"
          icon="📶"
          accessories={[{ text: "⏎ Open" }]}
          actions={
            <ActionPanel>
              <Action
                title="Open WiFi Manager"
                icon="📶"
                onAction={() => setSelectedManager("wifi")}
              />
            </ActionPanel>
          }
        />
        <List.Item
          title="Bluetooth Manager"
          subtitle="Manage Bluetooth devices and connections"
          icon="🔵"
          accessories={[{ text: "⏎ Open" }]}
          actions={
            <ActionPanel>
              <Action
                title="Open Bluetooth Manager"
                icon="🔵"
                onAction={() => setSelectedManager("bluetooth")}
              />
            </ActionPanel>
          }
        />
      </List.Section>
    </List>
  );
}
