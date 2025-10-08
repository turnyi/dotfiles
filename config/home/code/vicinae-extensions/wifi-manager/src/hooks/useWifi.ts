import { useState, useEffect } from "react";
import { WiFiNetwork } from "../types/wifi";
import { WiFiHelper } from "../helpers/wifiHelper";
import { showToast } from "@vicinae/api";

export const useWifi = () => {
  const [networks, setNetworks] = useState<WiFiNetwork[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [connecting, setConnecting] = useState<Set<string>>(new Set());

  const loadNetworks = async () => {
    try {
      setLoading(true);
      setError(null);

      showToast({ title: "Scanning networks..." });
      const scannedNetworks = await WiFiHelper.scanNetworks();
      showToast({ title: "Connect to wifi" });
      setNetworks(scannedNetworks);

      if (scannedNetworks.length === 0) {
        setError(
          "No networks found. Try rescanning or check if WiFi is enabled.",
        );
      }
    } catch (err) {
      setError("Failed to load networks. Please try again.");
      setNetworks([]);
    } finally {
      setLoading(false);
    }
  };

  const connect = async (ssid: string, password?: string) => {
    setConnecting((prev) => new Set(prev).add(ssid));
    showToast({ title: `Connecting to ${ssid}...` });
    try {
      const result = await WiFiHelper.connectToNetwork(ssid, password);
      showToast({
        style: result.success ? "success" : "failure",
        title: result.message || "Connection attempt completed",
      });
      if (result.success) {
        loadNetworks();
      }
      return result;
    } finally {
      setConnecting((prev) => {
        const newSet = new Set(prev);
        newSet.delete(ssid);
        return newSet;
      });
    }
  };

  const disconnect = async (ssid: string) => {
    showToast({ title: `Disconnecting from ${ssid}...` });
    const result = await WiFiHelper.disconnectFromNetwork(ssid);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Disconnection attempt completed",
    });
    if (result.success) {
      loadNetworks();
    }
    return result;
  };

  const forget = async (ssid: string) => {
    const result = await WiFiHelper.forgetNetwork(ssid);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Forget attempt completed",
    });
    if (result.success) {
      loadNetworks();
    }
    return result;
  };

  const rescan = async () => {
    showToast({ title: "Rescanning networks..." });
    try {
      await WiFiHelper.rescanNetworks();
      setTimeout(loadNetworks, 2000);
    } catch (err) {
      showToast({ style: "failure", title: "Failed to rescan networks" });
    }
  };

  useEffect(() => {
    loadNetworks();
    const interval = setInterval(loadNetworks, 15000);
    return () => clearInterval(interval);
  }, []);

  const knownNetworks = networks.filter((n) => n.known);
  const unknownNetworks = networks.filter((n) => !n.known);

  return {
    networks,
    knownNetworks,
    unknownNetworks,
    loading,
    error,
    connecting,
    connect,
    disconnect,
    forget,
    rescan,
    refresh: loadNetworks,
  };
};
