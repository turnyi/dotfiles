import { useState, useEffect } from "react";
import { BluetoothDevice } from "../types/bluetooth";
import { BluetoothHelper } from "../helpers/bluetoothHelper";
import { showToast } from "@vicinae/api";

export const useBluetooth = () => {
  const [devices, setDevices] = useState<BluetoothDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [scanning, setScanning] = useState(false);
  const [connecting, setConnecting] = useState<Set<string>>(new Set());

  const loadDevices = async (performActiveScan = false) => {
    setLoading(true);
    const scannedDevices = await BluetoothHelper.scanDevices(performActiveScan);
    setDevices(scannedDevices);
    setLoading(false);
  };

  const connect = async (address: string) => {
    setConnecting((prev) => new Set(prev).add(address));
    showToast({ title: "Connecting to device..." });
    try {
      const result = await BluetoothHelper.connectToDevice(address);
      showToast({
        style: result.success ? "success" : "failure",
        title: result.message || "Connection attempt completed",
      });
      if (result.success) {
        loadDevices();
      }
      return result;
    } finally {
      setConnecting((prev) => {
        const newSet = new Set(prev);
        newSet.delete(address);
        return newSet;
      });
    }
  };

  const disconnect = async (address: string) => {
    showToast({ title: "Disconnecting from device..." });
    const result = await BluetoothHelper.disconnectFromDevice(address);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Disconnection attempt completed",
    });
    if (result.success) {
      loadDevices();
    }
    return result;
  };

  const pair = async (address: string) => {
    showToast({ title: "Pairing with device..." });
    const result = await BluetoothHelper.pairDevice(address);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Pairing attempt completed",
    });
    if (result.success) {
      loadDevices();
    }
    return result;
  };

  const unpair = async (address: string) => {
    showToast({ title: "Unpairing device..." });
    const result = await BluetoothHelper.unpairDevice(address);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Unpairing attempt completed",
    });
    if (result.success) {
      loadDevices();
    }
    return result;
  };

  const startScan = async () => {
    setScanning(true);
    showToast({ title: "Starting Bluetooth scan..." });
    try {
      await loadDevices(true);
      showToast({ style: "success", title: "Scan completed" });
    } catch (error) {
      showToast({ style: "failure", title: "Scan failed" });
    } finally {
      setScanning(false);
    }
  };

  const stopScan = async () => {
    await BluetoothHelper.stopScan();
    setScanning(false);
  };

  useEffect(() => {
    loadDevices();
    const interval = setInterval(() => loadDevices(false), 15000);
    return () => {
      clearInterval(interval);
      stopScan();
    };
  }, []);

  const pairedDevices = devices.filter((d) => d.paired);
  const availableDevices = devices.filter((d) => !d.paired);

  return {
    devices,
    pairedDevices,
    availableDevices,
    loading,
    scanning,
    connect,
    disconnect,
    pair,
    unpair,
    startScan,
    stopScan,
    refresh: () => loadDevices(false),
  };
};
