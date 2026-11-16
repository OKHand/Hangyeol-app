import type { ApiError } from "../../../packages/contracts/src/index";
export class HttpError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number,
  ) {
    super(message);
  }
}
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (typeof init.body === "string")
    headers.set("Content-Type", "application/json");
  const response = await fetch(path.startsWith("/v1/") ? path : "/v1/" + path, {
    credentials: "include",
    ...init,
    headers,
  });
  const value = await response.json().catch(() => null);
  if (!response.ok)
    throw new HttpError(
      (value as ApiError)?.error?.code || "NETWORK_ERROR",
      (value as ApiError)?.error?.message ||
        "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.",
      response.status,
    );
  return value as T;
}
export const json = (body: unknown, method = "POST"): RequestInit => ({
  method,
  body: JSON.stringify(body),
});
