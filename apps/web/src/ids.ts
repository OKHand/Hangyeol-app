/** randomUUID is HTTPS-only; getRandomValues also works on the emulator's HTTP origin. */
export function createRequestId(): string {
  if (typeof globalThis.crypto?.getRandomValues !== "function") {
    throw new Error(
      "이 브라우저에서 요청 번호를 만들 수 없습니다. Android System WebView를 업데이트해 주세요.",
    );
  }
  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
