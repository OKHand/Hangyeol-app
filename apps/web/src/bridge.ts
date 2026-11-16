import { createRequestId } from "./ids";
import type {
  BridgeMethod,
  BridgeResponse,
} from "../../../packages/contracts/src/index";
declare global {
  interface Window {
    HangyeolBridge?: { postMessage(message: string): void };
    hangyeolBridgeReceive?: (response: BridgeResponse | string) => void;
    google?: any;
  }
}
const waiting = new Map<
  string,
  {
    resolve(value: unknown): void;
    reject(error: Error): void;
    timer: ReturnType<typeof setTimeout>;
  }
>();
window.hangyeolBridgeReceive = (value) => {
  let response: BridgeResponse;
  try {
    response = typeof value === "string" ? JSON.parse(value) : value;
  } catch {
    return;
  }
  if (response.bridgeVersion !== 1) return;
  const pending = waiting.get(response.requestId);
  if (!pending) return;
  waiting.delete(response.requestId);
  clearTimeout(pending.timer);
  response.error
    ? pending.reject(new Error(response.error.message))
    : pending.resolve(response.result);
};
export function nativeRequest<T = unknown>(
  method: BridgeMethod,
  params: Record<string, unknown> = {},
): Promise<T> {
  return new Promise((resolve, reject) => {
    if (!window.HangyeolBridge)
      return reject(new Error("이 기능은 한결씨드 앱에서 사용할 수 있습니다."));
    const id = createRequestId();
    const timer = setTimeout(() => {
      waiting.delete(id);
      reject(new Error("앱 응답을 받지 못했습니다. 다시 시도해 주세요."));
    }, 120_000);
    waiting.set(id, { resolve: (value) => resolve(value as T), reject, timer });
    window.HangyeolBridge.postMessage(
      JSON.stringify({ bridgeVersion: 1, requestId: id, method, params }),
    );
  });
}
export function openExternal(url: string): void {
  const parsed = new URL(url);
  if (parsed.protocol !== "https:")
    throw new Error("안전한 https 주소만 열 수 있습니다.");
  if (window.HangyeolBridge)
    void nativeRequest("external.open", { url }).catch((error) =>
      alert(error.message),
    );
  else window.open(url, "_blank", "noopener,noreferrer");
}
