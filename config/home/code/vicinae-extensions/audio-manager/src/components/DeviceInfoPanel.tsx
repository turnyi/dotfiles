import React from "react";
import { AudioDevice } from "../types/audio";
import { getDeviceTypeIcon } from "../helpers/icons";

interface DeviceInfoPanelProps {
  device: AudioDevice;
}

export function DeviceInfoPanel({ device }: DeviceInfoPanelProps) {
  const getConnectionTypeIcon = (type?: string): string => {
    switch (type) {
      case "usb":
        return "🔌";
      case "bluetooth":
        return "🔵";
      case "hdmi":
        return "📺";
      case "internal":
        return "💻";
      case "analog":
        return "🎧";
      default:
        return "🎵";
    }
  };

  const formatSampleRate = (rate?: string): string => {
    if (!rate) return "Unknown";
    // Convert Hz to kHz for readability
    const match = rate.match(/(\d+)\s*Hz/);
    if (match) {
      const hz = parseInt(match[1]);
      if (hz >= 1000) {
        return `${(hz / 1000).toFixed(1)} kHz`;
      }
    }
    return rate;
  };

  const getQualityIndicator = (
    sampleRate?: string,
    channels?: string,
  ): string => {
    if (!sampleRate) return "❓";

    const match = sampleRate.match(/(\d+)/);
    if (match) {
      const rate = parseInt(match[1]);
      const channelCount = channels?.includes("stereo") ? 2 : 1;

      if (rate >= 96000) return "🏆"; // Hi-res
      if (rate >= 48000) return "✨"; // High quality
      if (rate >= 44100) return "✅"; // CD quality
      if (rate >= 22050) return "📻"; // Radio quality
      return "📱"; // Basic quality
    }

    return "❓";
  };

  const hardwareInfo = device.hardwareInfo;

  return (
    <div
      style={{
        padding: "12px",
        backgroundColor: "#f5f5f5",
        borderRadius: "8px",
        fontFamily: "system-ui, -apple-system, sans-serif",
        fontSize: "13px",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "8px",
          marginBottom: "12px",
          borderBottom: "1px solid #ddd",
          paddingBottom: "8px",
        }}
      >
        <span style={{ fontSize: "18px" }}>
          {getDeviceTypeIcon(device.description)}
        </span>
        <div>
          <div style={{ fontWeight: "bold", fontSize: "14px" }}>
            {device.name}
          </div>
          <div style={{ color: "#666", fontSize: "12px" }}>
            {device.description}
          </div>
        </div>
      </div>

      <div
        style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}
      >
        <div>
          <h4 style={{ margin: "0 0 8px 0", fontSize: "12px", color: "#666" }}>
            DEVICE INFO
          </h4>

          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              marginBottom: "4px",
            }}
          >
            <span>Type:</span>
            <span style={{ fontWeight: "bold" }}>
              {device.type === "sink" ? "Output" : "Input"}
            </span>
          </div>

          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              marginBottom: "4px",
            }}
          >
            <span>Status:</span>
            <span
              style={{
                fontWeight: "bold",
                color:
                  device.status === "active"
                    ? "#4CAF50"
                    : device.status === "idle"
                      ? "#FF9800"
                      : "#757575",
              }}
            >
              {device.status.toUpperCase()}
            </span>
          </div>

          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              marginBottom: "4px",
            }}
          >
            <span>Default:</span>
            <span>{device.isDefault ? "✅ Yes" : "❌ No"}</span>
          </div>

          {hardwareInfo?.connectionType && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Connection:</span>
              <span>
                {getConnectionTypeIcon(hardwareInfo.connectionType)}{" "}
                {hardwareInfo.connectionType.toUpperCase()}
              </span>
            </div>
          )}

          {device.driver && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Driver:</span>
              <span style={{ fontSize: "11px", fontFamily: "monospace" }}>
                {device.driver}
              </span>
            </div>
          )}
        </div>

        <div>
          <h4 style={{ margin: "0 0 8px 0", fontSize: "12px", color: "#666" }}>
            AUDIO SPECS
          </h4>

          {hardwareInfo?.sampleRate && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Sample Rate:</span>
              <span>
                {getQualityIndicator(
                  hardwareInfo.sampleRate,
                  hardwareInfo.channels,
                )}{" "}
                {formatSampleRate(hardwareInfo.sampleRate)}
              </span>
            </div>
          )}

          {hardwareInfo?.channels && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Channels:</span>
              <span style={{ fontWeight: "bold" }}>
                {hardwareInfo.channels}
              </span>
            </div>
          )}

          {hardwareInfo?.sampleFormat && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Format:</span>
              <span style={{ fontFamily: "monospace", fontSize: "11px" }}>
                {hardwareInfo.sampleFormat}
              </span>
            </div>
          )}

          {hardwareInfo?.latency && (
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                marginBottom: "4px",
              }}
            >
              <span>Latency:</span>
              <span>{hardwareInfo.latency}</span>
            </div>
          )}
        </div>
      </div>

      {hardwareInfo?.activePort && (
        <div
          style={{
            marginTop: "12px",
            paddingTop: "8px",
            borderTop: "1px solid #ddd",
          }}
        >
          <h4 style={{ margin: "0 0 8px 0", fontSize: "12px", color: "#666" }}>
            ACTIVE PORT
          </h4>
          <div
            style={{
              padding: "6px 8px",
              backgroundColor: "#e8f5e8",
              borderRadius: "4px",
              fontSize: "12px",
            }}
          >
            🔌 {hardwareInfo.activePort}
          </div>

          {hardwareInfo.availablePorts &&
            hardwareInfo.availablePorts.length > 1 && (
              <div style={{ marginTop: "8px" }}>
                <div
                  style={{
                    fontSize: "11px",
                    color: "#666",
                    marginBottom: "4px",
                  }}
                >
                  Available ports: {hardwareInfo.availablePorts.length}
                </div>
                <div style={{ fontSize: "10px", color: "#999" }}>
                  {hardwareInfo.availablePorts
                    .filter((port) => port !== hardwareInfo.activePort)
                    .join(" • ")}
                </div>
              </div>
            )}
        </div>
      )}

      {device.hasActiveStreams && (
        <div
          style={{
            marginTop: "12px",
            padding: "8px",
            backgroundColor: "#e3f2fd",
            borderRadius: "4px",
            fontSize: "12px",
          }}
        >
          <span style={{ color: "#1976d2" }}>
            🎵 Active audio streams detected
          </span>
        </div>
      )}
    </div>
  );
}
