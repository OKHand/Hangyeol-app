import type {
  Photo,
  PhotoMetadata,
  UploadSession,
} from "../../../packages/contracts/src/index";
import { api, json } from "./api";
export interface Draft {
  id: string;
  userId: string;
  file: Blob;
  fileName: string;
  contentType: string;
  metadata: PhotoMetadata;
  createdAt: string;
  state: "queued" | "uploading" | "failed";
  error?: string;
}
const DB_NAME = "hangyeol-photo-drafts-v1";
export function openDrafts(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () =>
      req.result.createObjectStore("drafts", { keyPath: "id" });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
export async function saveDraft(draft: Draft): Promise<void> {
  const db = await openDrafts();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction("drafts", "readwrite");
      tx.objectStore("drafts").put(draft);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}
export async function listDrafts(userId: string): Promise<Draft[]> {
  const db = await openDrafts();
  try {
    return await new Promise((resolve, reject) => {
      const req = db.transaction("drafts").objectStore("drafts").getAll();
      req.onsuccess = () =>
        resolve(
          (req.result as Draft[])
            .filter((d) => d.userId === userId)
            .sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
        );
      req.onerror = () => reject(req.error);
    });
  } finally {
    db.close();
  }
}
export async function deleteDraft(id: string): Promise<void> {
  const db = await openDrafts();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction("drafts", "readwrite");
      tx.objectStore("drafts").delete(id);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}
const inFlight = new Map<string, Promise<Photo>>();
const controllers = new Map<string, AbortController>();
let queueOwner: string | null = null;
export function setQueueOwner(userId: string | null): void {
  if (queueOwner !== userId) {
    for (const controller of controllers.values()) controller.abort();
    controllers.clear();
    queueOwner = userId;
  }
}
export function cancelUploads(): void {
  for (const controller of controllers.values()) controller.abort();
  controllers.clear();
}

export function uploadDraft(draft: Draft): Promise<Photo> {
  if (queueOwner !== draft.userId)
    return Promise.reject(
      new Error("현재 계정과 사진의 등록 계정이 다릅니다."),
    );
  const existing = inFlight.get(draft.id);
  if (existing) return existing;
  const run = performUpload(draft).finally(() => inFlight.delete(draft.id));
  inFlight.set(draft.id, run);
  return run;
}
async function performUpload(draft: Draft): Promise<Photo> {
  const controller = new AbortController();
  controllers.set(draft.id, controller);
  const options = {
    signal: controller.signal,
    headers: { "X-Hangyeol-User": draft.userId },
  };
  await saveDraft({ ...draft, state: "uploading", error: undefined });
  try {
    const session = await api<UploadSession>("upload-sessions", {
      ...json({
        clientRequestId: draft.id,
        fileName: draft.fileName,
        contentType: draft.contentType,
        size: draft.file.size,
        metadata: draft.metadata,
      }),
      ...options,
    });
    if (session.status === "complete" && session.photo) {
      await deleteDraft(draft.id);
      return session.photo;
    }
    if (session.status !== "uploaded") {
      if (!session.uploadUrl.startsWith("/v1/upload-sessions/"))
        throw new Error("허용되지 않은 업로드 주소입니다.");
      const response = await fetch(session.uploadUrl, {
        method: "PUT",
        body: draft.file,
        credentials: "include",
        signal: controller.signal,
        headers: {
          "Content-Type": draft.contentType,
          "X-Hangyeol-User": draft.userId,
        },
      });
      if (!response.ok) {
        const result = await response.json().catch(() => null);
        throw new Error(
          result?.error?.message || "사진 전송을 완료하지 못했습니다.",
        );
      }
    }
    const result = await api<{ photo: Photo }>(
      "upload-sessions/" + session.id + "/complete",
      { ...json({}), ...options },
    );
    await deleteDraft(draft.id);
    return result.photo;
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : "연결을 확인한 후 다시 시도해 주세요.";
    await saveDraft({ ...draft, state: "failed", error: message });
    throw error;
  } finally {
    controllers.delete(draft.id);
  }
}
