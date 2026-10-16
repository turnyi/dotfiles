import {
  Action,
  ActionPanel,
  Icon,
  Image,
  List,
  closeMainWindow,
  showToast,
  Toast,
} from "@vicinae/api";
import React, { useMemo, useState } from "react";
import { Profile, openInProfile, readProfiles, toUrl } from "./chrome";

function loadProfiles(): { profiles: Profile[]; error?: string } {
  try {
    return { profiles: readProfiles() };
  } catch (error) {
    return { profiles: [], error: String(error) };
  }
}

export default function Command() {
  const [text, setText] = useState("");
  const { profiles, error } = useMemo(loadProfiles, []);
  const url = toUrl(text);
  const target = text.trim() ? url : "a new tab";

  async function open(profile: Profile, newWindow: boolean) {
    try {
      openInProfile(profile, url, newWindow);
      await closeMainWindow();
    } catch (err) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Couldn't open ${profile.name}`,
        message: String(err),
      });
    }
  }

  // The search bar is the URL, not a filter: there are only a handful of
  // profiles, and filtering would hide them all as soon as a URL is typed.
  return (
    <List
      filtering={false}
      searchText={text}
      onSearchTextChange={setText}
      searchBarPlaceholder="URL or search, then pick a profile"
    >
      {error ? (
        <List.EmptyView
          icon={Icon.Person}
          title="No Chrome profiles found"
          description={error}
        />
      ) : (
        <List.Section title={`Open ${target} in`}>
          {profiles.map((profile) => (
            <List.Item
              key={profile.directory}
              title={profile.name}
              subtitle={profile.email}
              icon={
                profile.avatar
                  ? { source: profile.avatar, mask: Image.Mask.Circle }
                  : Icon.Person
              }
              accessories={[{ text: profile.directory }]}
              actions={
                <ActionPanel>
                  <Action
                    title="Open Tab"
                    icon={Icon.Plus}
                    onAction={() => open(profile, false)}
                  />
                  <Action
                    title="Open in New Window"
                    icon={Icon.AppWindow}
                    shortcut={{ modifiers: ["cmd"], key: "return" }}
                    onAction={() => open(profile, true)}
                  />
                  <Action.CopyToClipboard
                    title="Copy Profile Directory"
                    content={profile.directory}
                  />
                </ActionPanel>
              }
            />
          ))}
        </List.Section>
      )}
    </List>
  );
}
