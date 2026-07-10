import { useEffect, useState } from "react";
import { Action, ActionPanel, Detail, Form, Icon, showToast, Toast } from "@vicinae/api";
import QRCode from "qrcode";
import { getNetworkPassword } from "../utils/nmcli";
import { buildWifiQrString, frequencyBand, isOpen, signalLabel } from "../utils/helpers";

interface Props {
  ssid: string;
  security: string;
  password?: string;
  signal?: number;
  channel?: number;
}

function QRView({
  ssid,
  security,
  password,
  signal,
  channel,
}: {
  ssid: string;
  security: string;
  password: string;
  signal?: number;
  channel?: number;
}) {
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  const open = isOpen(security);
  const wifiStr = buildWifiQrString(ssid, password, security);

  useEffect(() => {
    QRCode.toDataURL(wifiStr, {
      width: 280,
      margin: 2,
      color: { dark: "#ffffff", light: "#00000000" },
    })
      .then(setDataUrl)
      .catch(() => showToast({ style: Toast.Style.Failure, title: "Failed to generate QR code" }));
  }, [wifiStr]);

  const meta = [
    security && !open ? security : "Open",
    signal !== undefined ? `${signal}%  ${signalLabel(signal)}` : null,
    channel !== undefined ? frequencyBand(channel) || `Ch. ${channel}` : null,
  ]
    .filter(Boolean)
    .join("  ·  ");

  const markdown = dataUrl
    ? `# ${ssid}\n\n${meta}\n\n---\n\n![QR Code](${dataUrl})`
    : "Generating QR code…";

  return (
    <Detail
      navigationTitle={`Share "${ssid}"`}
      isLoading={!dataUrl}
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard
            title="Copy WiFi Data"
            content={`Network: ${ssid}\nPassword: ${password}`}
            shortcut={{ modifiers: ["ctrl"], key: "p" }}
            icon={Icon.BarCode}
          />
          <Action.CopyToClipboard
            title="Copy SSID"
            content={ssid}
            shortcut={{ modifiers: ["ctrl"], key: "c" }}
            icon={Icon.Wifi}
          />
          {!open && (
            <Action.CopyToClipboard
              title="Copy Password"
              content={password}
              shortcut={{ modifiers: ["ctrl", "shift"], key: "p" }}
              icon={Icon.Lock}
            />
          )}
        </ActionPanel>
      }
    />
  );
}

function PasswordForm({ ssid, onSubmit }: { ssid: string; onSubmit: (pwd: string) => void }) {
  return (
    <Form
      navigationTitle={`Share "${ssid}"`}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Generate QR Code"
            icon={Icon.BarCode}
            onSubmit={(values: { password: string }) => onSubmit(values.password)}
          />
        </ActionPanel>
      }
    >
      <Form.Description
        title="Password Required"
        text={`Enter the password for "${ssid}" to generate a shareable QR code.`}
      />
      <Form.PasswordField id="password" title="Password" placeholder="Wi-Fi password" autoFocus />
    </Form>
  );
}

export default function ShareView({ ssid, security, password: initialPassword, signal, channel }: Props) {
  const [step, setStep] = useState<"loading" | "qr" | "form">("loading");
  const [password, setPassword] = useState(initialPassword ?? "");
  const open = isOpen(security);

  useEffect(() => {
    if (open) { setStep("qr"); return; }
    if (initialPassword) { setStep("qr"); return; }
    getNetworkPassword(ssid).then((pwd) => {
      if (pwd !== null) {
        setPassword(pwd);
        setStep("qr");
      } else {
        setStep("form");
      }
    });
  }, [ssid, security, initialPassword, open]);

  if (step === "loading") return <Detail isLoading markdown="" navigationTitle={`Share "${ssid}"`} />;
  if (step === "form") {
    return (
      <PasswordForm
        ssid={ssid}
        onSubmit={(pwd) => {
          setPassword(pwd);
          setStep("qr");
        }}
      />
    );
  }
  return <QRView ssid={ssid} security={security} password={password} signal={signal} channel={channel} />;
}
