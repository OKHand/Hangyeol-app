import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { indexedDB } from "fake-indexeddb";
import {
  cancelUploads,
  deleteDraft,
  listDrafts,
  saveDraft,
  setQueueOwner,
  uploadDraft,
  type Draft,
} from "./queue.ts";
globalThis.indexedDB = indexedDB;
const meta = {
  farmName: "",
  crop: "",
  variety: "",
  address: "",
  memo: "",
  capturedAt: null,
  capturedAtSource: "unknown" as const,
};
function draft(id: string, userId = "owner"): Draft {
  return {
    id,
    userId,
    file: new Blob(["photo"], { type: "image/png" }),
    fileName: "field.png",
    contentType: "image/png",
    metadata: meta,
    createdAt: new Date().toISOString(),
    state: "queued",
  };
}
beforeEach(async () => {
  setQueueOwner("owner");
  for (const user of ["owner", "other"])
    for (const item of await listDrafts(user)) await deleteDraft(item.id);
});
test("drafts persist photo bytes and metadata scoped to the original account", async () => {
  await saveDraft(draft("first"));
  await saveDraft(draft("second", "other"));
  const saved = await listDrafts("owner");
  assert.equal(saved.length, 1);
  assert.equal(saved[0].id, "first");
  assert.equal(await saved[0].file.text(), "photo");
  assert.equal((await listDrafts("other"))[0].id, "second");
  await deleteDraft("first");
  assert.equal((await listDrafts("owner")).length, 0);
});
test("retry reuses the request identity and recovers already completed upload", async () => {
  const calls: { url: string; body?: unknown }[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), body: init?.body });
    assert.equal(new Headers(init?.headers).get("X-Hangyeol-User"), "owner");
    return Response.json({
      id: "session",
      status: "complete",
      uploadUrl: "/v1/upload-sessions/session/content",
      photo: { id: "saved" },
    });
  };
  try {
    const item = draft("stable-id");
    await saveDraft(item);
    assert.equal((await uploadDraft(item)).id, "saved");
    assert.equal(
      JSON.parse(calls[0].body as string).clientRequestId,
      "stable-id",
    );
    assert.equal(calls.length, 1);
    assert.equal((await listDrafts("owner")).length, 0);
  } finally {
    globalThis.fetch = original;
  }
});
test("network failures preserve the draft and original photo for retry", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => {
    throw new Error("offline");
  };
  try {
    const item = draft("failed");
    await assert.rejects(uploadDraft(item), /offline/);
    const saved = (await listDrafts("owner"))[0];
    assert.equal(saved.state, "failed");
    assert.equal(await saved.file.text(), "photo");
  } finally {
    globalThis.fetch = original;
  }
});
test("an old account draft cannot be sent with a new account session", async () => {
  setQueueOwner("other");
  await assert.rejects(
    uploadDraft(draft("old-account")),
    /등록 계정이 다릅니다/,
  );
  cancelUploads();
});
test("logout aborts an upload before another account can continue it", async () => {
  const original = globalThis.fetch;
  let started!: () => void;
  const began = new Promise<void>((resolve) => {
    started = resolve;
  });
  globalThis.fetch = async (_url, init) => {
    started();
    return new Promise((_resolve, reject) => {
      init?.signal?.addEventListener(
        "abort",
        () => reject(new Error("session ended")),
        { once: true },
      );
    });
  };
  try {
    const promise = uploadDraft(draft("cancel-me"));
    await began;
    setQueueOwner("other");
    await assert.rejects(promise, /session ended/);
    assert.equal((await listDrafts("owner"))[0].state, "failed");
    assert.equal((await listDrafts("other")).length, 0);
  } finally {
    globalThis.fetch = original;
  }
});
