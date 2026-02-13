import React, { useState } from "react";
import {
  Form,
  ActionPanel,
  Action,
  showToast,
  Toast,
  popToRoot,
  Icon,
} from "@vicinae/api";
import { addSnippet } from "./snippets";

export default function AddSnippet() {
  const [name, setName] = useState("");
  const [keyword, setKeyword] = useState("");
  const [content, setContent] = useState("");
  const [category, setCategory] = useState("general");

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Save Snippet"
            icon={Icon.Plus}
            onSubmit={async () => {
              if (!name.trim() || !keyword.trim() || !content.trim()) {
                await showToast({
                  style: Toast.Style.Failure,
                  title: "Missing fields",
                  message: "Name, keyword, and content are required",
                });
                return;
              }
              addSnippet({
                name: name.trim(),
                keyword: keyword.trim().startsWith(":")
                  ? keyword.trim()
                  : `:${keyword.trim()}`,
                content: content.trim(),
                category: category.trim() || "general",
              });
              await showToast({
                style: Toast.Style.Success,
                title: "Snippet saved",
              });
              popToRoot();
            }}
          />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="name"
        title="Name"
        placeholder="e.g. Email Address"
        value={name}
        onChange={setName}
      />
      <Form.TextField
        id="keyword"
        title="Keyword"
        placeholder="e.g. :email (auto-prefixed with : if missing)"
        value={keyword}
        onChange={setKeyword}
      />
      <Form.TextField
        id="category"
        title="Category"
        placeholder="e.g. personal, code, emoji"
        value={category}
        onChange={setCategory}
      />
      <Form.TextArea
        id="content"
        title="Content"
        placeholder="The text that will be pasted/copied"
        value={content}
        onChange={setContent}
      />
    </Form>
  );
}
