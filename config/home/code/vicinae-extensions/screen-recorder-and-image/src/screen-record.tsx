import React, { useState } from "react";
import {
  Form,
  ActionPanel,
  Action,
  showToast,
  Toast,
  Icon,
  closeMainWindow,
} from "@vicinae/api";
import { exec, spawn, ChildProcess } from "child_process";
import { promisify } from "util";
import path from "path";
import fs from "fs";

const execAsync = promisify(exec);

const DEFAULT_SAVE_PATH = `${process.env.HOME}/Videos/Screencasts`;

const listOutputs = async (): Promise<string[]> => {
  try {
    const { stdout } = await execAsync("hyprctl monitors -j");
    return JSON.parse(stdout).map((monitor: { name: string }) => monitor.name);
  } catch {
    return [];
  }
};

interface RecordingForm {
  output: string;
  region: string;
  recordAudio: boolean;
  savePath: string;
  filename: string;
}

const parseGeometry = (region: string): string | null => {
  const match = region.trim().match(/^(\d+x\d+)\+(\d+)\+(\d+)$/);
  return match ? `${match[2]},${match[3]} ${match[1]}` : null;
};

export default function ScreenRecord() {
  const [isLoading, setIsLoading] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingProcess, setRecordingProcess] = useState<ChildProcess | null>(
    null,
  );
  const [copyToClipboard, setCopyToClipboard] = useState(false);
  const [outputs, setOutputs] = useState<string[]>([]);
  const [defaultFilename, setDefaultFilename] = useState("");

  React.useEffect(() => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    setDefaultFilename(`recording-${timestamp}.mov`);
    listOutputs().then(setOutputs);
  }, []);

  const startRecording = async (formValues: Form.Values) => {
    const values = formValues as unknown as RecordingForm;
    setIsLoading(true);

    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
      const savePath = values.savePath || DEFAULT_SAVE_PATH;
      let filename = values.filename || "";

      if (filename.trim() === "" || filename.endsWith("/")) {
        filename = `recording-${timestamp}.mov`;
      }

      const fullPath = path.join(savePath, filename);

      if (!fs.existsSync(savePath)) {
        fs.mkdirSync(savePath, { recursive: true });
      }

      let command = "";
      let args: string[] = [];

      if (process.platform === "darwin") {
        command = "screencapture";
        args = ["-v", "-k", fullPath];
      } else if (process.platform === "linux") {
        try {
          await execAsync("which wf-recorder");
        } catch {
          throw new Error(
            "wf-recorder is not installed. Install it with: sudo pacman -S wf-recorder",
          );
        }

        command = "wf-recorder";
        args = ["-f", fullPath];

        const geometry = parseGeometry(values.region || "");

        if (geometry) {
          args.push("-g", geometry);
        } else {
          // wf-recorder prompts on stdin to pick a monitor when several exist and
          // neither -o nor -g is given; with no tty it exits 1 immediately.
          const output = values.output || outputs[0];

          if (!output) {
            throw new Error(
              "Could not determine which monitor to record. Enter a region instead.",
            );
          }

          args.push("-o", output);
        }

        if (values.recordAudio) {
          args.push("-a");
        }
      } else {
        throw new Error("Unsupported platform");
      }

      const child = spawn(command, args);

      setRecordingProcess(child);
      setIsRecording(true);

      child.stderr?.on("data", (data) => {
        console.log(`${command}:`, data.toString());
      });

      child.on("error", (error) => {
        showToast({
          style: Toast.Style.Failure,
          title: "Recording failed to start",
          message: error.message,
        });
        setIsRecording(false);
        setRecordingProcess(null);
      });

      child.on("exit", async (code, signal) => {
        setIsRecording(false);
        setRecordingProcess(null);

        // A SIGINT-terminated wf-recorder still finalises the file but reports
        // code null, so the file itself is the only reliable success signal.
        if (!fs.existsSync(fullPath)) {
          showToast({
            style: Toast.Style.Failure,
            title: "Recording failed",
            message: `${command} exited with ${signal ?? `code ${code}`} and wrote no file`,
          });
          return;
        }

        const quotedPath = JSON.stringify(fullPath);
        const copyCommand = process.platform === "darwin" ? "pbcopy" : "wl-copy";

        try {
          await execAsync(`printf %s ${quotedPath} | ${copyCommand}`);

          if (copyToClipboard) {
            await execAsync(`${copyCommand} < ${quotedPath}`);
          }
        } catch (clipboardError) {
          console.log("Failed to copy to clipboard:", clipboardError);
        }

        showToast({
          title: "Recording saved",
          message: `Saved to ${fullPath} (path copied to clipboard)${copyToClipboard ? " and file copied" : ""}`,
        });

        closeMainWindow();
      });

      await showToast({
        title: "Recording started",
        message: 'Click "Stop Recording" to finish',
      });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Recording failed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
      setIsRecording(false);
    } finally {
      setIsLoading(false);
    }
  };

  const stopRecording = async () => {
    if (!recordingProcess) {
      return;
    }

    await showToast({
      title: "Stopping recording...",
      message: "Please wait while the recording is being processed",
    });

    recordingProcess.kill("SIGINT");
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
              icon={copyToClipboard ? Icon.CheckCircle : Icon.Clipboard}
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
      <Form.Dropdown id="output" title="Monitor">
        {outputs.map((output) => (
          <Form.Dropdown.Item key={output} value={output} title={output} />
        ))}
      </Form.Dropdown>
      <Form.TextField
        id="region"
        title="Region"
        info="WIDTHxHEIGHT+X+Y (e.g. 1920x1080+0+0) — overrides the monitor"
      />
      <Form.Checkbox id="recordAudio" title="Audio" label="Record audio" />
      <Form.TextField
        id="savePath"
        title="Save Path"
        defaultValue={DEFAULT_SAVE_PATH}
      />
      <Form.TextField
        id="filename"
        title="Filename"
        defaultValue={defaultFilename}
      />
    </Form>
  );
}
