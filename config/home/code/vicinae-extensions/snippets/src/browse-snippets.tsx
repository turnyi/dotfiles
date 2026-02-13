import React, { useState, useEffect, useCallback } from "react";
import {
  List,
  ActionPanel,
  Action,
  Icon,
  Color,
  showToast,
  Toast,
  confirmAlert,
  Clipboard,
  closeMainWindow,
  PopToRootType,
} from "@vicinae/api";
import { exec } from "child_process";
import { loadSnippets, deleteSnippet, type Snippet } from "./snippets";

function pasteViaXdotool(text: string): void {
  const escaped = text.replace(/'/g, "'\\''");
  exec(`sleep 0.3 && xdotool type --clearmodifiers '${escaped}'`);
}

export default function BrowseSnippets() {
  const [snippets, setSnippets] = useState<Snippet[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(() => {
    setLoading(true);
    const data = loadSnippets();
    setSnippets(data);
    setLoading(false);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const categories = [...new Set(snippets.map((s) => s.category))].sort();

  const handleDelete = useCallback(
    async (snippet: Snippet) => {
      const confirmed = await confirmAlert({
        title: `Delete "${snippet.name}"?`,
        message: "This action cannot be undone.",
      });
      if (!confirmed) return;
      deleteSnippet(snippet.id);
      refresh();
      await showToast({
        style: Toast.Style.Success,
        title: "Snippet deleted",
      });
    },
    [refresh],
  );

  return (
    <List searchBarPlaceholder="Search snippets..." isLoading={loading}>
      {snippets.length === 0 && !loading ? (
        <List.EmptyView
          title="No snippets yet"
          description="Use 'Add Snippet' to create your first snippet"
        />
      ) : (
        categories.map((category) => (
          <List.Section key={category} title={category}>
            {snippets
              .filter((s) => s.category === category)
              .map((snippet) => (
                <List.Item
                  key={snippet.id}
                  title={snippet.name}
                  subtitle={
                    snippet.content.length > 60
                      ? snippet.content.slice(0, 60) + "..."
                      : snippet.content
                  }
                  accessories={[
                    {
                      tag: {
                        value: snippet.keyword,
                        color: Color.Blue,
                      },
                    },
                  ]}
                  actions={
                    <ActionPanel>
                      <Action.CopyToClipboard
                        title="Copy to Clipboard"
                        content={snippet.content}
                        icon={Icon.Clipboard}
                      />
                      <Action
                        title="Paste to Active Window"
                        icon={Icon.Text}
                        onAction={async () => {
                          await Clipboard.copy(snippet.content);
                          pasteViaXdotool(snippet.content);
                          await closeMainWindow({
                            clearRootSearch: true,
                            popToRootType: PopToRootType.Immediate,
                          });
                        }}
                      />
                      <Action
                        title="Delete Snippet"
                        icon={Icon.Trash}
                        onAction={() => handleDelete(snippet)}
                      />
                    </ActionPanel>
                  }
                />
              ))}
          </List.Section>
        ))
      )}
    </List>
  );
}
