import { useState, useEffect, useRef } from "react";
import { AudioDevice, AudioMonitoringData } from "../types/audio";
import { AudioHelper } from "../helpers/audioHelper";

interface UseAudioMonitoringProps {
  devices: AudioDevice[];
  enabled?: boolean;
  updateInterval?: number;
  throttleUpdates?: boolean;
}

export const useAudioMonitoring = ({
  devices,
  enabled = true,
  updateInterval = 1000,
}: UseAudioMonitoringProps) => {
  const [monitoringData, setMonitoringData] = useState<AudioMonitoringData>({
    levels: {},
    activeStreams: [],
    lastUpdate: 0,
  });
  const [isMonitoring, setIsMonitoring] = useState(false);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const mountedRef = useRef(true);

  const startMonitoring = async () => {
    if (!enabled || devices.length === 0) return;

    setIsMonitoring(true);

    const updateMonitoringData = async () => {
      if (!mountedRef.current) return;

      try {
        const data = await AudioHelper.getMonitoringData(devices);
        if (mountedRef.current) {
          setMonitoringData(data);
        }
      } catch (error) {
        console.error("Failed to update monitoring data:", error);
      }
    };

    // Initial update
    await updateMonitoringData();

    // Set up interval for continuous monitoring
    intervalRef.current = setInterval(updateMonitoringData, updateInterval);
  };

  const stopMonitoring = () => {
    setIsMonitoring(false);
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  };

  const getDeviceLevel = (deviceId: string) => {
    return monitoringData.levels[deviceId];
  };

  const getDeviceStreams = (deviceId: string) => {
    return monitoringData.activeStreams.filter(
      (stream) => stream.deviceId === deviceId,
    );
  };

  const hasActiveStreams = (deviceId: string) => {
    return getDeviceStreams(deviceId).length > 0;
  };

  // Enhanced device data with monitoring information
  const enhancedDevices = devices.map((device) => ({
    ...device,
    currentLevel: getDeviceLevel(device.id)?.currentLevel || 0,
    peakLevel: getDeviceLevel(device.id)?.peakLevel || 0,
    hasActiveStreams: hasActiveStreams(device.id),
  }));

  useEffect(() => {
    mountedRef.current = true;

    if (enabled && devices.length > 0) {
      startMonitoring();
    } else {
      stopMonitoring();
    }

    return () => {
      mountedRef.current = false;
      stopMonitoring();
    };
  }, [enabled, devices.length, updateInterval]);

  // Restart monitoring when device list changes
  useEffect(() => {
    if (isMonitoring) {
      stopMonitoring();
      startMonitoring();
    }
  }, [devices]);

  return {
    monitoringData,
    enhancedDevices,
    isMonitoring,
    startMonitoring,
    stopMonitoring,
    getDeviceLevel,
    getDeviceStreams,
    hasActiveStreams,
  };
};
