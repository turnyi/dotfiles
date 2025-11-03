import React, { useState } from "react";
import {
  Form,
  ActionPanel,
  Action,
  showToast,
  Icon,
  closeMainWindow,
} from "@vicinae/api";
import { exec } from "child_process";
import { promisify } from "util";
import path from "path";
import fs from "fs";

const execAsync = promisify(exec);

interface ScreenshotForm {
  captureType: string;
  savePath: string[];
  copyToClipboard: boolean;
  filename: string;
}

export default function Screenshot() {
  const [isLoading, setIsLoading] = useState(false);

  const handleScreenshot = async (values: Form.Values) => {
    const formData = values as ScreenshotForm;
    setIsLoading(true);

    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
      const defaultFilename =
        formData.filename || `screenshot-${timestamp}.png`;
      const savePath = formData.savePath?.[0] || process.env.HOME + "/Desktop";
      const fullPath = path.join(savePath, defaultFilename);

      let command = "";

      // Build screencapture command based on platform
      if (process.platform === "darwin") {
        // macOS
        switch (formData.captureType) {
          case "fullscreen":
            command = `screencapture "${fullPath}"`;
            break;
          case "window":
            command = `screencapture -w "${fullPath}"`;
            break;
          case "selection":
            command = `screencapture -s "${fullPath}"`;
            break;
        }
      } else if (process.platform === "linux") {
        // Linux with gnome-screenshot
        switch (formData.captureType) {
          case "fullscreen":
            command = `gnome-screenshot -f "${fullPath}"`;
            break;
          case "window":
            command = `gnome-screenshot -w -f "${fullPath}"`;
            break;
          case "selection":
            command = `gnome-screenshot -a -f "${fullPath}"`;
            break;
        }
      }

      if (command) {
        await execAsync(command);

        // Copy to clipboard if requested
        if (formData.copyToClipboard && fs.existsSync(fullPath)) {
          if (process.platform === "darwin") {
            await execAsync(
              `osascript -e 'set the clipboard to (read (POSIX file "${fullPath}") as JPEG picture)'`,
            );
          } else if (process.platform === "linux") {
            await execAsync(
              `xclip -selection clipboard -t image/png -i "${fullPath}"`,
            );
          }
        }

        await showToast({
          title: "Screenshot taken",
          message: `Saved to ${fullPath}${formData.copyToClipboard ? " and copied to clipboard" : ""}`,
        });

        closeMainWindow();
      } else {
        throw new Error("Unsupported platform");
      }
    } catch (error) {
      await showToast({
        style: "failure",
        title: "Screenshot failed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Take Screenshot"
            icon={Icon.Camera}
            onSubmit={handleScreenshot}
          />
        </ActionPanel>
      }
    >
      <Form.Dropdown
        id="captureType"
        title="Capture Type"
        defaultValue="fullscreen"
      >
        <Form.Dropdown.Item
          title="Full Screen"
          value="fullscreen"
          icon={Icon.Monitor}
        />
        <Form.Dropdown.Item
          title="Window"
          value="window"
          icon={Icon.AppWindow}
        />
        <Form.Dropdown.Item
          title="Selection"
          value="selection"
          icon={Icon.Crop}
        />
      </Form.Dropdown>

      <Form.TextField
        id="filename"
        title="Filename"
        placeholder="screenshot-2024-01-01.png"
        info="Optional custom filename (will auto-generate if empty)"
      />

      <Form.FilePicker
        id="savePath"
        title="Save Location"
        info="Choose where to save the screenshot"
      />

      <Form.Checkbox
        id="copyToClipboard"
        title="Copy to Clipboard"
        label="Also copy screenshot to clipboard"
        defaultValue={true}
      />
    </Form>
  );
}
