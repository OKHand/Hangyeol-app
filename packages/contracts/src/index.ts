/** Shared HTTP and native bridge contract. No credentials belong in these models. */
export type Role = "owner" | "admin" | "member" | "viewer";
export interface User {
  id: string;
  email: string;
  name: string;
  role: Role;
  organizationId: string;
}
export type PhotoStatus = "needs_info" | "ready";
export interface PhotoMetadata {
  farmName: string;
  crop: string;
  variety: string;
  address: string;
  memo: string;
  capturedAt: string | null;
  capturedAtSource: "exif" | "device" | "manual" | "unknown";
  latitude?: number | null;
  longitude?: number | null;
  locationSource?: "exif" | "device" | "manual" | "unknown";
}
export interface Photo extends PhotoMetadata {
  id: string;
  number: string;
  organizationId: string;
  revision: number;
  createdAt: string;
  updatedAt: string;
  createdBy: string;
  source: "app" | "discord";
  status: PhotoStatus;
  imageUrl: string;
  fileName: string;
  contentType: string;
  size: number;
}
export interface UploadRequest {
  clientRequestId: string;
  fileName: string;
  contentType: string;
  size: number;
  metadata: PhotoMetadata;
}
export interface UploadSession {
  id: string;
  uploadUrl: string;
  status: "pending" | "uploaded" | "complete";
  photo?: Photo;
}
export interface PhotoList {
  items: Photo[];
  nextCursor: string | null;
}
export interface Job {
  id: string;
  photoId: string;
  type: "sheets" | "discord";
  status: "pending" | "done" | "blocked" | "failed";
  attempts: number;
  message: string;
  updatedAt: string;
}
export interface Bootstrap {
  mode: "development" | "production";
  googleClientId?: string;
  devAuthEnabled?: boolean;
  features: {
    photos: boolean;
    erp: boolean;
    discord: boolean;
    sheets: boolean;
  };
  erpUrl: string | null;
  bridgeVersion: number;
}
export interface ApiError {
  error: { code: string; message: string; requestId?: string };
}
export type BridgeMethod =
  | "capabilities.get"
  | "camera.capture"
  | "photos.pick"
  | "location.request"
  | "uploads.enqueue"
  | "uploads.status"
  | "uploads.retry"
  | "external.open"
  | "session.logout";
export interface BridgeRequest {
  bridgeVersion: 1;
  requestId: string;
  method: BridgeMethod;
  params?: Record<string, unknown>;
}
export interface BridgeResponse {
  bridgeVersion: 1;
  requestId: string;
  result?: unknown;
  error?: { code: string; message: string };
}
