import { useState, useEffect } from "react";
import { AudioDevice, AudioDeviceInfo } from "../types/audio";
import { AudioHelper } from "../helpers/audioHelper";
import { showToast } from "@vicinae/api";

export const useAudio = () => {
  const [deviceInfo, setDeviceInfo] = useState<AudioDeviceInfo>({
    sinks: [],
    sources: [],
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [operationInProgress, setOperationInProgress] = useState<Set<string>>(
    new Set(),
  );

  const loadDevices = async () => {
    try {
      setLoading(true);
      setError(null);

      showToast({ title: "Scanning audio devices..." });
      const devices = await AudioHelper.getAudioDevices();
      setDeviceInfo(devices);

      if (devices.sinks.length === 0 && devices.sources.length === 0) {
        setError("No audio devices found. Check if PulseAudio is running.");
      }
    } catch (err) {
      setError("Failed to load audio devices. Please try again.");
      setDeviceInfo({ sinks: [], sources: [] });
    } finally {
      setLoading(false);
    }
  };

  const setDefaultDevice = async (
    deviceId: string,
    type: "sink" | "source",
  ) => {
    setOperationInProgress((prev) => new Set(prev).add(deviceId));
    showToast({ title: `Setting ${deviceId} as default ${type}...` });

    try {
      const result = await AudioHelper.setDefaultDevice(deviceId, type);
      showToast({
        style: result.success ? "success" : "failure",
        title: result.message || "Operation completed",
      });

      if (result.success) {
        loadDevices();
      }
      return result;
    } finally {
      setOperationInProgress((prev) => {
        const newSet = new Set(prev);
        newSet.delete(deviceId);
        return newSet;
      });
    }
  };

  const setVolume = async (
    deviceId: string,
    type: "sink" | "source",
    volume: number,
  ) => {
    try {
      const result = await AudioHelper.setDeviceVolume(deviceId, type, volume);
      if (!result.success) {
        showToast({
          style: "failure",
          title: result.message || "Failed to set volume",
        });
      }

      // Update local state immediately for better UX
      setDeviceInfo((prev) => ({
        ...prev,
        [type === "sink" ? "sinks" : "sources"]: prev[
          type === "sink" ? "sinks" : "sources"
        ].map((device) =>
          device.id === deviceId ? { ...device, volume } : device,
        ),
      }));

      return result;
    } catch (err) {
      showToast({ style: "failure", title: "Failed to set volume" });
      return { success: false, message: "Failed to set volume" };
    }
  };

  const toggleMute = async (
    deviceId: string,
    type: "sink" | "source",
    mute?: boolean,
  ) => {
    const device =
      type === "sink"
        ? deviceInfo.sinks.find((d) => d.id === deviceId)
        : deviceInfo.sources.find((d) => d.id === deviceId);

    if (!device) return { success: false, message: "Device not found" };

    const newMuteState = mute !== undefined ? mute : !device.muted;

    try {
      const result = await AudioHelper.toggleDeviceMute(
        deviceId,
        type,
        newMuteState,
      );
      if (result.success) {
        // Update local state immediately for better UX
        setDeviceInfo((prev) => ({
          ...prev,
          [type === "sink" ? "sinks" : "sources"]: prev[
            type === "sink" ? "sinks" : "sources"
          ].map((d) => (d.id === deviceId ? { ...d, muted: newMuteState } : d)),
        }));
      } else {
        showToast({
          style: "failure",
          title: result.message || "Failed to toggle mute",
        });
      }
      return result;
    } catch (err) {
      showToast({ style: "failure", title: "Failed to toggle mute" });
      return { success: false, message: "Failed to toggle mute" };
    }
  };

  const testDevice = async (deviceId: string) => {
    showToast({ title: "Playing test sound..." });
    const result = await AudioHelper.testDevice(deviceId);
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Test completed",
    });
    return result;
  };

  const increaseVolume = async (
    deviceId: string,
    type: "sink" | "source",
    increment: number = 10,
  ) => {
    const result = await AudioHelper.increaseDeviceVolume(
      deviceId,
      type,
      increment,
    );
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Volume operation completed",
    });
    if (result.success) {
      loadDevices();
    }
    return result;
  };

  const decreaseVolume = async (
    deviceId: string,
    type: "sink" | "source",
    decrement: number = 10,
  ) => {
    const result = await AudioHelper.decreaseDeviceVolume(
      deviceId,
      type,
      decrement,
    );
    showToast({
      style: result.success ? "success" : "failure",
      title: result.message || "Volume operation completed",
    });
    if (result.success) {
      loadDevices();
    }
    return result;
  };

  const refresh = async () => {
    showToast({ title: "Refreshing audio devices..." });
    await loadDevices();
  };

  useEffect(() => {
    loadDevices();
    // Refresh devices every 10 seconds to catch hardware changes
    const interval = setInterval(loadDevices, 10000);
    return () => clearInterval(interval);
  }, []);

  return {
    sinks: deviceInfo.sinks,
    sources: deviceInfo.sources,
    defaultSink: deviceInfo.defaultSink,
    defaultSource: deviceInfo.defaultSource,
    loading,
    error,
    operationInProgress,
    setDefaultDevice,
    setVolume,
    increaseVolume,
    decreaseVolume,
    toggleMute,
    testDevice,
    refresh,
    reload: loadDevices,
  };
};
