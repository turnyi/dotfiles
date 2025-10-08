import React, { useState } from "react";
import { Form, ActionPanel, Action } from "@vicinae/api";
import { getSignalIcon } from "../helpers/signalHelper";

interface ConnectionFormProps {
  title: string;
  placeholder: string;
  onConnect: (input: string) => void;
  onCancel: () => void;
  isPassword?: boolean;
  networkName?: string;
  signal?: number;
}

export function ConnectionForm({
  onConnect,
  onCancel,
  networkName,
  signal,
}: ConnectionFormProps) {
  const [input, setInput] = useState("");

  const networkInfo = networkName
    ? `Connect to: ${networkName} ${getSignalIcon(signal)}`
    : `${getSignalIcon(signal)} WiFi Network`;

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Connect"
            onSubmit={() => onConnect(input)}
          />
          <Action title="Cancel" onAction={onCancel} />
        </ActionPanel>
      }
      navigationTitle={networkInfo}
    >
      <Form.TextField id="info" title="Network" value={networkInfo} />
      <Form.TextField
        id="input"
        title="Password"
        value={input}
        onChange={setInput}
        autoFocus
      />
    </Form>
  );
}
