import React from "react";
import { AudioDevice } from "../types/audio";

interface AudioLevelMeterProps {
  device: AudioDevice;
  showPeak?: boolean;
  compact?: boolean;
}

export function AudioLevelMeter({
  device,
  showPeak = true,
  compact = false,
}: AudioLevelMeterProps) {
  const currentLevel = device.currentLevel || 0;
  const peakLevel = device.peakLevel || 0;

  // Normalize levels (0-100)
  const normalizedCurrent = Math.min(100, Math.max(0, currentLevel));
  const normalizedPeak = Math.min(100, Math.max(0, peakLevel));

  const getLevelColor = (level: number): string => {
    if (level >= 85) return "#ff4444"; // Red - clipping/danger
    if (level >= 70) return "#ff8800"; // Orange - loud
    if (level >= 40) return "#44ff44"; // Green - good
    if (level >= 10) return "#88ff88"; // Light green - quiet
    return "#444444"; // Dark - silent
  };

  const getLevelBars = (level: number): string => {
    const bars = Math.ceil(level / 10);
    const activeColor = getLevelColor(level);

    if (compact) {
      // Compact version with fewer characters
      return "█".repeat(Math.max(0, bars)) + "░".repeat(Math.max(0, 10 - bars));
    } else {
      // Full version with color indication
      const activeBars = "█".repeat(Math.max(0, bars));
      const inactiveBars = "░".repeat(Math.max(0, 10 - bars));
      return activeBars + inactiveBars;
    }
  };

  const getActivityIndicator = (): string => {
    if (device.muted) return "🔇";
    if (currentLevel > 50) return "🔊";
    if (currentLevel > 20) return "🔉";
    if (currentLevel > 0) return "🔈";
    return "🔇";
  };

  const getLevelText = (): string => {
    if (device.muted) return "MUTED";
    if (currentLevel === 0) return "SILENT";
    if (currentLevel < 5) return "QUIET";
    if (currentLevel < 30) return "LOW";
    if (currentLevel < 70) return "NORMAL";
    if (currentLevel < 85) return "LOUD";
    return "PEAK";
  };

  if (compact) {
    return (
      <span
        title={`Current: ${normalizedCurrent}% ${showPeak ? `| Peak: ${normalizedPeak}%` : ""}`}
      >
        {getActivityIndicator()} {getLevelBars(normalizedCurrent)}
      </span>
    );
  }

  return (
    <div
      style={{
        fontFamily: "monospace",
        fontSize: "12px",
        display: "flex",
        flexDirection: "column",
        gap: "2px",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
        <span>{getActivityIndicator()}</span>
        <span style={{ minWidth: "60px" }}>{getLevelText()}</span>
        <span
          style={{
            color: getLevelColor(normalizedCurrent),
            fontWeight: "bold",
          }}
        >
          {getLevelBars(normalizedCurrent)}
        </span>
        <span style={{ minWidth: "35px", fontSize: "10px" }}>
          {normalizedCurrent.toFixed(0)}%
        </span>
      </div>

      {showPeak && peakLevel > 0 && (
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <span>📊</span>
          <span style={{ minWidth: "60px", fontSize: "10px", color: "#888" }}>
            PEAK
          </span>
          <span
            style={{
              color: getLevelColor(normalizedPeak),
              fontWeight: "bold",
              opacity: 0.7,
            }}
          >
            {getLevelBars(normalizedPeak)}
          </span>
          <span style={{ minWidth: "35px", fontSize: "10px", color: "#888" }}>
            {normalizedPeak.toFixed(0)}%
          </span>
        </div>
      )}

      {device.hasActiveStreams && (
        <div style={{ fontSize: "10px", color: "#4CAF50" }}>
          ● Active audio streams
        </div>
      )}
    </div>
  );
}
