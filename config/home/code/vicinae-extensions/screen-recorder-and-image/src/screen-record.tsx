import React, { useState } from "react";
import {
  Form,
  ActionPanel,
  Action,
  showToast,
  Icon,
  closeMainWindow,
} from "@vicinae/api";
import { exec, spawn } from "child_process";
import { promisify } from "util";
import path from "path";
import fs from "fs";

const execAsync = promisify(exec);

interface RecordingForm {
  recordAudio: boolean;
  recordMicrophone: boolean;
  savePath: string[];
  filename: string;
  region: string;
}

export default function ScreenRecord() {
  const [isLoading, setIsLoading] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingProcess, setRecordingProcess] = useState<any>(null);
  const [copyToClipboard, setCopyToClipboard] = useState(false);
  const [defaultFilename, setDefaultFilename] = useState("");

  // Generate default filename on component mount
  React.useEffect(() => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    setDefaultFilename(`recording-${timestamp}.mov`);
  }, []);

  const startRecording = async (values: Form.Values) => {
    console.log("startRecording called with values:", values);
    setIsLoading(true);

    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
      let filename = values.filename || `recording-${timestamp}.mov`;
      const savePath = values.savePath || "/home/turny/Videos/Screencasts";

      // If filename ends with /, use just date and time
      if (filename.endsWith("/") || filename.trim() === "") {
        filename = `recording-${timestamp}.mov`;
      }

      const fullPath = path.join(savePath, filename);

      // Create directory if it doesn't exist
      if (!fs.existsSync(savePath)) {
        fs.mkdirSync(savePath, { recursive: true });
      }

      let command = "";
      let args: string[] = [];

      if (process.platform === "darwin") {
        // macOS using screencapture for recording
        command = "screencapture";
        args = ["-v", "-k"]; // video recording with audio
        args.push(fullPath);
      } else if (process.platform === "linux") {
        // Linux - try to find the best available screen recorder
        const region = values.region || "fullscreen";

        // Try wf-recorder first (Wayland)
        try {
          console.log("Checking for wf-recorder...");
          await execAsync("which wf-recorder");
          console.log("wf-recorder found!");
          command = "wf-recorder";

          if (region === "fullscreen") {
            args = ["-f", fullPath];
          } else {
            // wf-recorder region format: x,y WIDTHxHEIGHT
            const parts = region.split("+");
            if (parts.length === 3) {
              const size = parts[0]; // WIDTHxHEIGHT
              const x = parts[1];
              const y = parts[2];
              args = ["-g", `${x},${y} ${size}`, "-f", fullPath];
            } else {
              args = ["-f", fullPath];
            }
          }
          console.log("Using wf-recorder for Wayland");
        } catch (error) {
          console.log("wf-recorder not found, trying alternatives:", error);
          // Fallback to OBS Studio if available
          try {
            await execAsync("which obs");
            throw new Error(
              "OBS detected but requires manual setup. Please use wf-recorder or install it with: sudo pacman -S wf-recorder",
            );
          } catch (obsError) {
            // Fallback to ffmpeg as last resort
            try {
              await execAsync("which ffmpeg");
              command = "ffmpeg";

              // Detect display server
              const isWayland = process.env.WAYLAND_DISPLAY;

              if (isWayland) {
                throw new Error(
                  "Wayland detected but wf-recorder not available. Install with: sudo pacman -S wf-recorder",
                );
              }

              // X11 fallback
              const display = process.env.DISPLAY || ":0";
              args = [
                "-f",
                "x11grab",
                "-video_size",
                region === "fullscreen" ? "1920x1080" : region.split("+")[0],
                "-framerate",
                "30",
                "-i",
                region === "fullscreen"
                  ? display
                  : display + "+" + region.split("+").slice(1).join("+"),
                "-c:v",
                "libx264",
                "-preset",
                "ultrafast",
                "-crf",
                "18",
                fullPath,
              ];
              console.log("Using ffmpeg for X11");
            } catch (ffmpegError) {
              throw new Error(
                "No screen recording tool found. Please install wf-recorder: sudo pacman -S wf-recorder",
              );
            }
          }
        }
      }

      console.log("Command:", command, "Args:", args, "Full path:", fullPath);

      // Test if command exists
      try {
        await execAsync(`which ${command}`);
        console.log(`${command} is available`);
      } catch (error) {
        throw new Error(`${command} is not installed or not in PATH`);
      }

      if (command) {
        await showToast({
          title: "Starting recording...",
          message: `Command: ${command} ${args.join(" ")}`,
        });

        // For Linux, we need to handle X11 authorization properly
        const spawnOptions = {
          env: {
            ...process.env,
            DISPLAY: process.env.DISPLAY || ":0",
            XAUTHORITY:
              process.env.XAUTHORITY || process.env.HOME + "/.Xauthority",
          },
        };

        const process = spawn(command, args, spawnOptions);
        console.log("Process PID:", process.pid);
        setRecordingProcess(process);
        setIsRecording(true);

        process.stdout?.on("data", (data) => {
          console.log("ffmpeg stdout:", data.toString());
        });

        process.stderr?.on("data", (data) => {
          console.log("ffmpeg stderr:", data.toString());
        });

        process.on("error", (error) => {
          console.log("Process error:", error);
          showToast({
            style: "failure",
            title: "Recording failed to start",
            message: error.message,
          });
          setIsRecording(false);
          setRecordingProcess(null);
        });

        process.on("exit", async (code) => {
          console.log("Process exited with code:", code);
          setIsRecording(false);
          setRecordingProcess(null);

          if (code === 0) {
            // Always copy file path to clipboard
            try {
              if (process.platform === "linux") {
                await execAsync(`echo "${fullPath}" | wl-copy`);
              } else if (process.platform === "darwin") {
                await execAsync(`echo "${fullPath}" | pbcopy`);
              }
            } catch (clipboardError) {
              console.error(
                "Failed to copy file path to clipboard:",
                clipboardError,
              );
            }

            // Copy file content to clipboard if requested
            if (copyToClipboard && fs.existsSync(fullPath)) {
              try {
                if (process.platform === "linux") {
                  await execAsync(`wl-copy < "${fullPath}"`);
                } else if (process.platform === "darwin") {
                  await execAsync(`pbcopy < "${fullPath}"`);
                }
              } catch (clipboardError) {
                console.error(
                  "Failed to copy file content to clipboard:",
                  clipboardError,
                );
              }
            }

            showToast({
              title: "Recording saved",
              message: `Saved to ${fullPath} (path copied to clipboard)${copyToClipboard ? " and file copied" : ""}`,
            });

            // Close Vicinae after successful recording
            closeMainWindow();
          } else {
            showToast({
              style: "failure",
              title: "Recording failed",
              message: `Process exited with code ${code}`,
            });
          }
        });

        await showToast({
          title: "Recording started",
          message: 'Click "Stop Recording" button to finish',
        });
      } else {
        throw new Error("Unsupported platform");
      }
    } catch (error) {
      await showToast({
        style: "failure",
        title: "Recording failed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
      setIsRecording(false);
    } finally {
      setIsLoading(false);
    }
  };

  const stopRecording = async () => {
    console.log("stopRecording called, recordingProcess:", recordingProcess);
    if (recordingProcess) {
      console.log("Killing process with PID:", recordingProcess.pid);

      await showToast({
        title: "Stopping recording...",
        message: "Please wait while the recording is being processed",
      });

      recordingProcess.kill("SIGINT"); // Graceful stop

      // Don't immediately set states - let the exit handler do that
      // setRecordingProcess(null);
      // setIsRecording(false);
    }
  };

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          {!isRecording && (
            <Action.SubmitForm
              title="Start Recording"
              icon={Icon.Video}
              onSubmit={startRecording}
            />
          )}
          {!isRecording && (
            <Action
              title={
                copyToClipboard
                  ? "Don't Copy to Clipboard"
                  : "Copy to Clipboard"
              }
              icon={copyToClipboard ? Icon.ClipboardChecked : Icon.Clipboard}
              onAction={() => setCopyToClipboard(!copyToClipboard)}
            />
          )}
          {isRecording && (
            <Action
              title="Stop Recording"
              icon={Icon.Stop}
              style={Action.Style.Destructive}
              onAction={stopRecording}
            />
          )}
        </ActionPanel>
      }
    >
      <Form.TextField
        id="savePath"
        title="Save Path"
        value="/home/turny/Videos/Screencasts"
      />
      <Form.TextField
        id="region"
        title="Region"
        placeholder="fullscreen | WIDTHxHEIGHT+X+Y (e.g. 1920x1080+0+0)"
        value="fullscreen"
      />
      <Form.TextField
        id="filename"
        title="Filename"
        value={defaultFilename}
        placeholder="recording-2024-01-01.mov"
      />
    </Form>
  );
}
