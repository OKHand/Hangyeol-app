import { useEffect, useRef } from "react";
import type { User } from "../../../packages/contracts/src/index";
import { api, json } from "./api";
function errorMessage(e: unknown) {
  return e instanceof Error ? e.message : "Google 로그인에 실패했습니다.";
}
export function GoogleLogin({
  clientId,
  onSuccess,
  onError,
}: {
  clientId: string;
  onSuccess(user: User): void;
  onError(message: string): void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let active = true;
    const initialize = () => {
      if (window.HangyeolBridge) return;
      if (!active || !ref.current || !window.google) return;
      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: async ({ credential }: { credential: string }) => {
          try {
            const result = await api<{ user: User }>(
              "auth/google",
              json({ credential }),
            );
            onSuccess(result.user);
          } catch (e) {
            onError(errorMessage(e));
          }
        },
      });
      window.google.accounts.id.renderButton(ref.current, {
        theme: "outline",
        size: "large",
        text: "signin_with",
        locale: "ko",
      });
    };
    if (window.google?.accounts) initialize();
    else {
      let script = document.querySelector<HTMLScriptElement>(
        "script[data-google-login]",
      );
      if (!script) {
        script = document.createElement("script");
        script.src = "https://accounts.google.com/gsi/client";
        script.async = true;
        script.dataset.googleLogin = "true";
        document.head.append(script);
      }
      script.addEventListener("load", initialize);
    }
    return () => {
      active = false;
    };
  }, [clientId]);
  return <div ref={ref} className="google-login" />;
}
