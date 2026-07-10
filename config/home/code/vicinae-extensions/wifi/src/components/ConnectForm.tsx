import { Action, ActionPanel, Form, showToast, Toast, useNavigation } from "@vicinae/api";
import { connectToNetwork } from "../utils/nmcli";
import { frequencyBand, signalLabel } from "../utils/helpers";

interface Props {
  ssid: string;
  signal: number;
  security: string;
  channel: number;
  onConnected: () => void;
}

export default function ConnectForm({ ssid, signal, security, channel, onConnected }: Props) {
  const { pop } = useNavigation();

  const handleSubmit = async (values: { password: string }) => {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Connecting to ${ssid}…` });
    const result = await connectToNetwork(ssid, values.password);
    if (result.success) {
      toast.style = Toast.Style.Success;
      toast.title = "Connected";
      toast.message = ssid;
      onConnected();
      pop();
    } else {
      toast.style = Toast.Style.Failure;
      toast.title = "Connection failed";
      toast.message = result.error ?? "Wrong password?";
    }
  };

  const band = frequencyBand(channel) || `Ch. ${channel}`;

  return (
    <Form
      navigationTitle={`Connect to ${ssid}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Connect" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description title="Network" text={ssid} />
      <Form.Description title="Signal" text={`${signal}%  ·  ${signalLabel(signal)}  ·  ${band}`} />
      <Form.Description title="Security" text={security} />
      <Form.Separator />
      <Form.PasswordField id="password" title="Password" placeholder="Enter network password" autoFocus />
    </Form>
  );
}
