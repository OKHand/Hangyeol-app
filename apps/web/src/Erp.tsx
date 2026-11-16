import { GoogleLogin } from "./GoogleLogin";
import { useEffect, useRef, useState, type FormEvent } from "react";
import type { User } from "../../../packages/contracts/src/index";
import { api, json } from "./api";
const modes = ["입고", "출고", "통합", "요약", "집계", "재고"] as const;
const fields = [
  ["customers", "거래처명", "customer"],
  ["divs", "구분", "div"],
  ["items", "품목", "item"],
  ["sales", "판매품종명", "sales"],
  ["origins", "원품종명", "origin"],
] as const;
interface Props {
  user: User;
  googleClientId?: string;
  onUser(user: User): void;
}
interface Result {
  success: boolean;
  message?: string;
  data?: string[][];
  engineRevision: string;
}
export function Erp({ user, googleClientId, onUser }: Props) {
  const [native, setNative] = useState(!!window.HangyeolBridge);
  useEffect(() => {
    const ready = () => setNative(true);
    window.addEventListener("hangyeol-bridge-ready", ready);
    return () => window.removeEventListener("hangyeol-bridge-ready", ready);
  }, []);
  const [mode, setMode] = useState<(typeof modes)[number]>("출고");
  const [status, setStatus] = useState<{
    configured: boolean;
    authorized: boolean;
    authMode?: "pc-admin" | "google";
  } | null>(null);
  const [values, setValues] = useState<Record<string, string>>({}),
    [options, setOptions] = useState<Record<string, string[]>>({});
  const [start, setStart] = useState(""),
    [end, setEnd] = useState(""),
    [view, setView] = useState("A"),
    [stock, setStock] = useState("규격별");
  const [result, setResult] = useState<Result | null>(null),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [font, setFont] = useState(13);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => {
    let active = true;
    void api<{ configured: boolean; authorized: boolean }>("erp/status")
      .then((s) => {
        if (active) setStatus(s);
      })
      .catch((e) => {
        if (active) setError(e.message);
      });
    return () => {
      active = false;
      pending.current?.abort();
    };
  }, [user.id]);
  useEffect(() => {
    let active = true;
    if (status?.configured && status.authorized)
      void api<Record<string, string[]>>("erp/suggestions")
        .then((v) => {
          if (active) setOptions(v);
        })
        .catch((e) => {
          if (active) setError(e.message);
        });
    return () => {
      active = false;
    };
  }, [status]);
  useEffect(() => {
    pending.current?.abort();
    setBusy(false);
    setError("");
    setResult(null);
    setFont(13);
  }, [mode]);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (start && end && start > end) {
      setError("시작일이 종료일보다 늦습니다.");
      return;
    }
    pending.current?.abort();
    const controller = new AbortController();
    pending.current = controller;
    setBusy(true);
    try {
      const params: Record<string, unknown> = {
        mode,
        startDate: start,
        endDate: end,
        view: mode === "집계" ? view : mode === "재고" ? stock : undefined,
      };
      for (const [key] of fields)
        params[key] = (values[key] || "")
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
      const data = await api<Result>("erp/queries", {
        ...json(params),
        signal: controller.signal,
      });
      if (controller.signal.aborted) return;
      if (!data.success) {
        setError(data.message || "조건에 맞는 내역이 없습니다.");
        return;
      }
      setResult(data);
      setFont(13);
    } catch (e) {
      if (!controller.signal.aborted)
        setError(
          e instanceof Error ? e.message : "조회를 완료하지 못했습니다.",
        );
    } finally {
      if (!controller.signal.aborted) setBusy(false);
    }
  }
  const header = result?.data?.[1] || [],
    columns = header.flatMap((h, i) => (h && h !== "System_UID" ? [i] : []));
  if (result?.data)
    return (
      <section className="erp-workspace">
        <div className="section-heading">
          <button className="secondary" onClick={() => setResult(null)}>
            ← 조회 조건
          </button>
          <div className="actions">
            <span className="small muted">글자 크기</span>
            <button
              className="secondary"
              aria-label="ERP 글자 확대"
              onClick={() => setFont((f) => Math.min(25, f + 1))}
            >
              +
            </button>
            <button
              className="secondary"
              aria-label="ERP 글자 축소"
              onClick={() => setFont((f) => Math.max(2, f - 1))}
            >
              −
            </button>
          </div>
        </div>
        <p className="erp-condition">{result.data[0]?.[0]}</p>
        <div className="erp-grid-wrap">
          <table className="erp-grid" style={{ fontSize: font }}>
            <thead>
              <tr>
                {columns.map((i) => (
                  <th key={i}>{header[i]}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {result.data.slice(2).map((row, r) => (
                <tr key={r}>
                  {columns.map((i) => (
                    <td
                      key={i}
                      className={
                        /^-?[\d,]+(?:\.\d+)?$/.test(row[i] || "")
                          ? "erp-number"
                          : ""
                      }
                    >
                      {row[i] ?? ""}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    );
  return (
    <section className="erp-workspace">
      <div className="page-heading">
        <div>
          <span className="eyebrow">입출고 업무</span>
          <h1>ERP 조회</h1>
          <p>입고·출고·통합·요약·집계·재고를 앱 안에서 조회합니다.</p>
        </div>
      </div>
      {error && (
        <div className="notice" role="alert">
          {error}
        </div>
      )}
      {status && !status.configured && (
        <div className="notice">
          <b>ERP 연결 설정이 필요합니다.</b>
          <p>
            PC에서 ERP-연결설정.cmd를 실행하면 실제 자료를 조회할 수 있습니다.
            Google Cloud 프로젝트는 필요하지 않습니다.
          </p>
        </div>
      )}
      {status &&
        status.configured &&
        status.authMode === "google" &&
        !status.authorized && (
          <div className="panel">
            <h2>관리자 연결 확인</h2>
            <p>
              ERP는 연결이 허용된 관리자만 조회할 수 있습니다. PC 관리자 또는
              설정된 Google 계정으로 연결해 주세요.
            </p>
            {!native && googleClientId ? (
              <GoogleLogin
                clientId={googleClientId}
                onSuccess={onUser}
                onError={setError}
              />
            ) : (
              <p className="small muted">
                앱은 PC 관리자 연결을 사용합니다. PC에서 ERP-연결설정.cmd를
                실행해 주세요.
              </p>
            )}
            {!googleClientId && (
              <p className="small muted">
                관리자의 앱용 Google 로그인 설정이 아직 완료되지 않았습니다.
              </p>
            )}
          </div>
        )}
      <nav className="erp-tabs" aria-label="ERP 조회 유형">
        {modes.map((m) => (
          <button
            className={mode === m ? "active" : ""}
            key={m}
            onClick={() => setMode(m)}
          >
            {m}
          </button>
        ))}
      </nav>
      <form className="panel erp-form" onSubmit={submit}>
        {mode !== "재고" && (
          <>
            {fields.map(([key, label, option]) => (
              <label key={key}>
                {label}
                <input
                  aria-label={"ERP " + label}
                  list={"erp-options-" + key}
                  placeholder={
                    key === "customers" ? "예: 가명A종묘 (이름 일부로 조회)" : ""
                  }
                  value={values[key] || ""}
                  onChange={(e) =>
                    setValues((v) => ({ ...v, [key]: e.target.value }))
                  }
                />
                <datalist id={"erp-options-" + key}>
                  {(options[option] || []).map((v) => (
                    <option key={v} value={v} />
                  ))}
                </datalist>
              </label>
            ))}
            <div className="erp-dates">
              <label>
                시작일
                <input
                  type="date"
                  value={start}
                  onChange={(e) => setStart(e.target.value)}
                />
              </label>
              <span>~</span>
              <label>
                종료일
                <input
                  type="date"
                  value={end}
                  onChange={(e) => setEnd(e.target.value)}
                />
              </label>
            </div>
          </>
        )}
        {mode === "집계" && (
          <label>
            집계 형식
            <select value={view} onChange={(e) => setView(e.target.value)}>
              <option value="A">선택 거래처 품목별 집계</option>
              <option value="B">품목 중심 거래처별 집계</option>
              <option value="C">거래처 중심 품목별 집계</option>
            </select>
          </label>
        )}
        {mode === "재고" && (
          <label>
            재고 조회 형식
            <select value={stock} onChange={(e) => setStock(e.target.value)}>
              <option>규격별</option>
              <option>총량</option>
            </select>
          </label>
        )}
        <div className="actions">
          <button
            className="secondary"
            type="button"
            onClick={() => {
              setValues({});
              setStart("");
              setEnd("");
              setError("");
            }}
          >
            초기화
          </button>
          <button
            className="primary"
            disabled={busy || !status?.configured || !status.authorized}
          >
            {busy ? "조회 중…" : "조회 확인"}
          </button>
        </div>
      </form>
    </section>
  );
}
