import { GoogleLogin } from "./GoogleLogin";
import { Erp } from "./Erp";
import { createRequestId } from "./ids";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type FormEvent,
  type ReactNode,
} from "react";
import * as exifr from "exifr";
import type {
  Bootstrap,
  Job,
  Photo,
  PhotoList,
  PhotoMetadata,
  User,
} from "../../../packages/contracts/src/index";
import { api, HttpError, json } from "./api";
import {
  cancelUploads,
  deleteDraft,
  listDrafts,
  saveDraft,
  setQueueOwner,
  uploadDraft,
  type Draft,
} from "./queue";
import { nativeRequest } from "./bridge";

type Page = "home" | "photos" | "erp" | "settings";
type Asset = {
  handle: string;
  fileName: string;
  size: number;
  contentType: string;
  capturedAt?: string | null;
  capturedAtSource?: "device" | "unknown";
};
type NativeUpload = {
  id: string;
  state: string;
  fileName: string;
  error?: string;
};
const blankMetadata = (): PhotoMetadata => ({
  farmName: "",
  crop: "",
  variety: "",
  address: "",
  memo: "",
  capturedAt: null,
  capturedAtSource: "unknown",
  locationSource: "unknown",
  latitude: null,
  longitude: null,
});
const dateLabel = (value: string | null) =>
  value
    ? new Intl.DateTimeFormat("ko-KR", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        timeZone: "Asia/Seoul",
      }).format(new Date(value))
    : "촬영일 미상";
const dateInput = (value: string | null) =>
  value
    ? new Date(new Date(value).getTime() + 9 * 3_600_000)
        .toISOString()
        .slice(0, 16)
    : "";
const icons = { home: "⌂", photos: "▧", erp: "≡", settings: "⋯" };
const names = {
  home: "홈",
  photos: "작황 사진",
  erp: "ERP",
  settings: "더보기",
};
function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "처리하지 못했습니다. 다시 시도해 주세요.";
}

let initialSession: Promise<{ boot: Bootstrap; user: User | null }> | null =
  null;
function startSession() {
  if (!initialSession) {
    const ticket = new URLSearchParams(location.hash.slice(1)).get(
      "session_ticket",
    );
    if (ticket)
      history.replaceState(null, "", location.pathname + location.search);
    initialSession = (async () => {
      const boot = await api<Bootstrap>("bootstrap");
      if (ticket) await api("web-sessions/exchange", json({ ticket }));
      try {
        const result = await api<{ user: User }>("me");
        return { boot, user: result.user };
      } catch (e) {
        if (e instanceof HttpError && e.status === 401)
          return { boot, user: null };
        throw e;
      }
    })();
  }
  return initialSession;
}

export function App() {
  const [boot, setBoot] = useState<Bootstrap | null>(null),
    [user, setUser] = useState<User | null>(null),
    [ready, setReady] = useState(false);
  const [page, setPage] = useState<Page>("home"),
    [error, setError] = useState(""),
    [toast, setToast] = useState("");
  const [nativeReady, setNativeReady] = useState(
    Boolean(window.HangyeolBridge),
  );
  const [online, setOnline] = useState(navigator.onLine),
    [photos, setPhotos] = useState<Photo[]>([]),
    [nextCursor, setNextCursor] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Draft[]>([]),
    [nativeUploads, setNativeUploads] = useState<NativeUpload[]>([]),
    [jobs, setJobs] = useState<Job[]>([]);
  const [loading, setLoading] = useState(false),
    [filters, setFilters] = useState({
      farm: "",
      crop: "",
      region: "",
      from: "",
      to: "",
      status: "",
      dateBasis: "captured",
    });
  const [appliedFilters, setAppliedFilters] = useState(filters),
    [edit, setEdit] = useState<Photo | null>(null),
    [selected, setSelected] = useState<File | Asset | null>(null);
  const [detail, setDetail] = useState<Photo | null>(null),
    [busy, setBusy] = useState(false);
  const pickRef = useRef<HTMLInputElement>(null),
    cameraRef = useRef<HTMLInputElement>(null),
    queueBusy = useRef(false);
  const refreshQueue = useCallback(async () => {
    if (!user) return;
    setDrafts(await listDrafts(user.id));
    if (window.HangyeolBridge) {
      try {
        const result = await nativeRequest<{ items: NativeUpload[] }>(
          "uploads.status",
        );
        setNativeUploads(result.items || []);
      } catch {
        /* Browser queue remains available. */
      }
    }
  }, [user]);
  const loadPhotos = useCallback(
    async (cursor?: string) => {
      if (!user) return;
      setLoading(true);
      try {
        const params = new URLSearchParams();
        Object.entries(appliedFilters).forEach(([key, value]) => {
          if (value) params.set(key, value);
        });
        if (cursor) params.set("cursor", cursor);
        const result = await api<PhotoList>("photos?" + params);
        setPhotos((old) =>
          cursor
            ? [
                ...old,
                ...result.items.filter((p) => !old.some((q) => q.id === p.id)),
              ]
            : result.items,
        );
        setNextCursor(result.nextCursor);
      } catch (e) {
        setError(errorMessage(e));
      } finally {
        setLoading(false);
      }
    },
    [user, appliedFilters],
  );
  const loadJobs = useCallback(async () => {
    if (user)
      try {
        const result = await api<{ items: Job[] }>("jobs");
        setJobs(result.items);
      } catch (e) {
        setError(errorMessage(e));
      }
  }, [user]);
  useEffect(() => {
    let active = true;
    void startSession()
      .then((result) => {
        if (active) {
          setBoot(result.boot);
          setUser(result.user);
        }
      })
      .catch((e) => {
        if (active) setError(errorMessage(e));
      })
      .finally(() => {
        if (active) setReady(true);
      });
    const on = () => setOnline(true),
      off = () => setOnline(false);
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    return () => {
      active = false;
      window.removeEventListener("online", on);
      window.removeEventListener("offline", off);
    };
  }, []);
  useEffect(() => {
    const ready = () => setNativeReady(Boolean(window.HangyeolBridge));
    window.addEventListener("hangyeol-bridge-ready", ready);
    ready();
    return () => window.removeEventListener("hangyeol-bridge-ready", ready);
  }, []);
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(""), 6000);
      return () => clearTimeout(timer);
    }
  }, [toast]);
  useEffect(() => {
    setQueueOwner(user?.id || null);
    return () => cancelUploads();
  }, [user]);
  useEffect(() => {
    void loadPhotos();
    void refreshQueue();
    void loadJobs();
  }, [loadPhotos, refreshQueue, loadJobs]);
  useEffect(() => {
    if (!user || !nativeReady) return;
    void refreshQueue();
    const timer = setInterval(() => {
      void refreshQueue();
      if (document.visibilityState === "visible") void loadPhotos();
    }, 5000);
    return () => clearInterval(timer);
  }, [user, nativeReady, refreshQueue, loadPhotos]);
  const retryQueue = useCallback(async () => {
    if (!user || !online || queueBusy.current) return;
    queueBusy.current = true;
    try {
      for (const draft of await listDrafts(user.id)) {
        try {
          await uploadDraft(draft);
        } catch (e) {
          setToast(
            "업로드가 중단되었습니다. 대기 목록에서 다시 시도할 수 있습니다.",
          );
          if (!navigator.onLine) break;
        }
      }
      await refreshQueue();
      await loadPhotos();
      await loadJobs();
    } finally {
      queueBusy.current = false;
    }
  }, [user, online, refreshQueue, loadPhotos, loadJobs]);
  useEffect(() => {
    if (user && online) void retryQueue();
  }, [user, online]); // Resume persisted drafts only on login/reconnect.
  const login = async () => {
    setBusy(true);
    setError("");
    try {
      const result = await api<{ user: User }>("auth/dev", json({}));
      setUser(result.user);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };
  const logout = async () => {
    cancelUploads();
    setQueueOwner(null);
    setBusy(true);
    try {
      await api("auth/logout", json({}));
      setUser(null);
      setPhotos([]);
      setDrafts([]);
      setNativeUploads([]);
      setDetail(null);
      setSelected(null);
      if (window.HangyeolBridge)
        await nativeRequest("session.logout").catch(() => {});
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };
  async function choosePhoto(camera: boolean) {
    if (window.HangyeolBridge) {
      try {
        const caps = await nativeRequest<{ camera: boolean }>(
          "capabilities.get",
        );
        const result = await nativeRequest<{ assets: Asset[] }>(
          camera && caps.camera ? "camera.capture" : "photos.pick",
          { multiple: false },
        );
        if (result.assets?.[0]) setSelected(result.assets[0]);
      } catch (e) {
        setError(errorMessage(e));
      }
    } else (camera ? cameraRef : pickRef).current?.click();
  }
  function filePicked(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (file) {
      if (!["image/jpeg", "image/png", "image/webp"].includes(file.type))
        return setError("JPG, PNG, WebP 사진을 선택해 주세요.");
      if (file.size > 20 * 1024 * 1024)
        return setError("사진은 한 장당 20MB 이하로 선택해 주세요.");
      setSelected(file);
    }
  }
  async function savePhoto(metadata: PhotoMetadata) {
    if (!user) return;
    setBusy(true);
    setError("");
    try {
      if (edit) {
        const result = await api<{ photo: Photo }>(
          "photos/" + edit.id,
          json({ ...metadata, revision: edit.revision }, "PATCH"),
        );
        setDetail(result.photo);
        setEdit(null);
        setToast("사진 정보를 수정했습니다.");
        await loadPhotos();
        await loadJobs();
        return;
      }
      if (!selected) return;
      if (!(selected instanceof File)) {
        await nativeRequest("uploads.enqueue", {
          handle: selected.handle,
          metadata,
        });
        setSelected(null);
        setToast(
          "앱 업로드 목록에 저장했습니다. 진행 상태는 더보기에서 확인할 수 있습니다.",
        );
        await refreshQueue();
        await loadPhotos();
        return;
      }
      const draft: Draft = {
        id: createRequestId(),
        userId: user.id,
        file: selected,
        fileName: selected.name,
        contentType: selected.type,
        metadata,
        createdAt: new Date().toISOString(),
        state: "queued",
      };
      await saveDraft(draft);
      setSelected(null);
      await refreshQueue();
      if (navigator.onLine) {
        try {
          await uploadDraft(draft);
          setToast("사진을 등록했습니다.");
          await loadPhotos();
          await loadJobs();
        } catch (e) {
          setToast(
            "사진을 기기에 보관했습니다. 연결 후 업로드를 다시 시도해 주세요.",
          );
        }
      } else setToast("사진을 기기에 보관했습니다. 연결되면 업로드합니다.");
      await refreshQueue();
    } catch (e) {
      setError(errorMessage(e));
      throw e;
    } finally {
      setBusy(false);
    }
  }
  const pending =
    drafts.length + nativeUploads.filter((u) => u.state !== "complete").length;
  if (!ready)
    return (
      <div className="loading-screen">
        <Brand />
        <p>업무 공간을 준비하고 있습니다…</p>
      </div>
    );
  if (!user)
    return (
      <div className="login-layout">
        <div className="login-story">
          <Brand />
          <span className="eyebrow">현장에서 회사까지, 하나로</span>
          <h1>
            오늘의 작황을
            <br />
            내일의 기록으로.
          </h1>
          <p>
            농가의 사진과 정보를 모으고
            <br />
            한결씨드의 업무를 이어갑니다.
          </p>
          <div className="field-art" aria-hidden="true">
            <span />
            <span />
            <span />
            <span />
            <span />
          </div>
        </div>
        <section className="login-card">
          <span className="pill">한결씨드 업무 플랫폼</span>
          <h2>반갑습니다</h2>
          <p>승인된 계정으로 업무 공간에 들어오세요.</p>
          {error && <Notice close={() => setError("")}>{error}</Notice>}
          {boot?.mode === "development" && boot.devAuthEnabled ? (
            <>
              <button className="primary wide" disabled={busy} onClick={login}>
                {busy ? "연결 중…" : "개발용 관리자 계정으로 시작"}
              </button>
              <p className="small muted">
                개발 환경입니다. Google 계정 연결 없이 기능을 확인할 수
                있습니다.
              </p>
              {boot.googleClientId && (
                <GoogleLogin
                  clientId={boot.googleClientId}
                  onSuccess={setUser}
                  onError={setError}
                />
              )}
            </>
          ) : boot?.googleClientId ? (
            <GoogleLogin
              clientId={boot.googleClientId}
              onSuccess={setUser}
              onError={setError}
            />
          ) : (
            <p className="notice">
              Google 로그인이 아직 연결되지 않았습니다. 관리자가 연결한 뒤
              이용할 수 있습니다.
            </p>
          )}
          <div className="login-foot">
            회사 자료는 승인된 구성원에게만 표시됩니다.
          </div>
        </section>
      </div>
    );
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Brand />
        <span className="workspace-label">우리의 업무 공간</span>
        <nav aria-label="주 메뉴">
          {(Object.keys(names) as Page[]).map((item) => (
            <button
              key={item}
              className={page === item ? "nav active" : "nav"}
              onClick={() => {
                setPage(item);
                setError("");
              }}
            >
              <span aria-hidden="true">{icons[item]}</span>
              {names[item]}
            </button>
          ))}
        </nav>
        <div className="sidebar-foot">
          <span className="avatar">{user.name.slice(0, 1)}</span>
          <div>
            <b>{user.name}</b>
            <small>{user.role === "owner" ? "관리자" : "구성원"}</small>
          </div>
          <button
            className="icon-btn"
            aria-label="로그아웃"
            onClick={logout}
            disabled={busy}
          >
            ↗
          </button>
        </div>
      </aside>
      <main>
        <header className="topbar">
          <div className="mobile-brand">
            <Brand />
          </div>
          <span className="breadcrumb">
            한결씨드 <span>/</span> {names[page]}
          </span>
          <div className="topbar-right">
            {boot?.mode === "development" && (
              <span className="dev-label">개발 환경</span>
            )}
            <span className={"connection " + (online ? "" : "offline")}>
              {online ? "연결됨" : "오프라인"}
            </span>
          </div>
        </header>
        <div className="page-content">
          {error && <Notice close={() => setError("")}>{error}</Notice>}
          {!online && (
            <div className="notice">
              인터넷 연결이 끊겼습니다. 새 사진은 기기에 보관한 뒤 연결되면
              전송합니다.
            </div>
          )}
          {page === "home" && (
            <>
              <div className="page-heading">
                <div>
                  <span className="eyebrow">한결의 하루</span>
                  <h1>안녕하세요, {user.name}님</h1>
                  <p>현장의 기록을 모으고, 필요한 업무를 바로 시작하세요.</p>
                </div>
                <span className="today">
                  {dateLabel(new Date().toISOString())}
                </span>
              </div>
              <section className="hero">
                <div>
                  <span className="eyebrow">FIELD NOTES</span>
                  <h2>
                    작물의 변화를
                    <br />
                    사진 한 장에 담으세요.
                  </h2>
                  <p>
                    촬영일, 농가, 품종을 함께 기록하면
                    <br />
                    필요할 때 더 쉽게 찾을 수 있습니다.
                  </p>
                  <div className="actions">
                    <button
                      className="primary"
                      onClick={() => choosePhoto(true)}
                    >
                      ＋ 사진 촬영
                    </button>
                    <button
                      className="secondary"
                      onClick={() => choosePhoto(false)}
                    >
                      사진 불러오기
                    </button>
                  </div>
                </div>
                <div className="hero-graphic" aria-hidden="true">
                  <div className="leaf leaf-one" />
                  <div className="leaf leaf-two" />
                  <div className="leaf leaf-three" />
                  <div className="stem" />
                  <div className="graphic-label">오늘의 기록이 쌓입니다</div>
                </div>
              </section>
              <div className="summary-grid">
                <button
                  className="summary-card"
                  onClick={() => setPage("photos")}
                >
                  <span>조회된 사진</span>
                  <strong>
                    {photos.length}
                    <small>장</small>
                  </strong>
                  <em>앨범 열기 →</em>
                </button>
                <button
                  className="summary-card"
                  onClick={() => setPage("settings")}
                >
                  <span>업로드 대기</span>
                  <strong>
                    {pending}
                    <small>건</small>
                  </strong>
                  <em>
                    {pending ? "진행 상태 확인 →" : "모두 전송되었습니다"}
                  </em>
                </button>
                <button
                  className="summary-card"
                  onClick={() => {
                    setFilters((f) => ({ ...f, status: "needs_info" }));
                    setAppliedFilters((f) => ({ ...f, status: "needs_info" }));
                    setPage("photos");
                  }}
                >
                  <span>정보 보완 필요</span>
                  <strong>
                    {photos.filter((p) => p.status === "needs_info").length}
                    <small>장</small>
                  </strong>
                  <em>농가·작물 정보 입력 →</em>
                </button>
              </div>
              <section>
                <div className="section-heading">
                  <h2>최근 기록</h2>
                  <button
                    className="text-btn"
                    onClick={() => setPage("photos")}
                  >
                    전체 보기 →
                  </button>
                </div>
                {photos.length ? (
                  <PhotoGrid photos={photos.slice(0, 4)} onSelect={setDetail} />
                ) : (
                  <Empty
                    title="첫 번째 현장 기록을 남겨 보세요"
                    text="촬영한 사진이나 앨범의 사진을 불러오면 이곳에 모입니다."
                    action={
                      <button
                        className="secondary"
                        onClick={() => choosePhoto(false)}
                      >
                        사진 추가
                      </button>
                    }
                  />
                )}
              </section>
            </>
          )}
          {page === "photos" && (
            <>
              <div className="page-heading">
                <div>
                  <span className="eyebrow">우리의 현장 기록</span>
                  <h1>작황 사진</h1>
                  <p>농가와 작물의 변화를 차곡차곡 살펴보세요.</p>
                </div>
                <button className="primary" onClick={() => choosePhoto(false)}>
                  ＋ 사진 등록
                </button>
              </div>
              <form
                className="filter-panel"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (filters.from && filters.to && filters.from > filters.to)
                    return setError("시작일이 종료일보다 늦습니다.");
                  setError("");
                  setAppliedFilters({ ...filters });
                }}
              >
                <div className="filter-search">
                  <Field label="농가명">
                    <input
                      placeholder="농가명 검색"
                      value={filters.farm}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, farm: e.target.value }))
                      }
                    />
                  </Field>
                  <Field label="작물">
                    <input
                      placeholder="예: 토마토"
                      value={filters.crop}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, crop: e.target.value }))
                      }
                    />
                  </Field>
                  <Field label="지역">
                    <input
                      placeholder="주소 일부"
                      value={filters.region}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, region: e.target.value }))
                      }
                    />
                  </Field>
                </div>
                <div className="filter-dates">
                  <Field label="날짜 기준">
                    <select
                      value={filters.dateBasis}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, dateBasis: e.target.value }))
                      }
                    >
                      <option value="captured">촬영일</option>
                      <option value="created">등록일</option>
                    </select>
                  </Field>
                  <Field label="시작일">
                    <input
                      type="date"
                      value={filters.from}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, from: e.target.value }))
                      }
                    />
                  </Field>
                  <Field label="종료일">
                    <input
                      type="date"
                      value={filters.to}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, to: e.target.value }))
                      }
                    />
                  </Field>
                  <Field label="정보 상태">
                    <select
                      value={filters.status}
                      onChange={(e) =>
                        setFilters((f) => ({ ...f, status: e.target.value }))
                      }
                    >
                      <option value="">전체</option>
                      <option value="needs_info">보완 필요</option>
                      <option value="ready">입력 완료</option>
                    </select>
                  </Field>
                  <button className="primary" type="submit" disabled={loading}>
                    조회
                  </button>
                  <button
                    className="text-btn"
                    type="button"
                    onClick={() => {
                      const clean = {
                        farm: "",
                        crop: "",
                        region: "",
                        from: "",
                        to: "",
                        status: "",
                        dateBasis: "captured",
                      };
                      setFilters(clean);
                      setAppliedFilters(clean);
                    }}
                  >
                    초기화
                  </button>
                </div>
              </form>
              <div className="section-heading">
                <span className="muted small">
                  {loading
                    ? "사진을 불러오고 있습니다…"
                    : `${photos.length}장의 사진${nextCursor ? " · 더 보기 가능" : ""}`}
                </span>
                <button className="text-btn" onClick={() => loadPhotos()}>
                  ↻ 새로고침
                </button>
              </div>
              {photos.length ? (
                <PhotoGrid photos={photos} onSelect={setDetail} />
              ) : (
                <Empty
                  title="조회된 사진이 없습니다"
                  text="새 사진을 등록하거나 검색 조건을 바꿔 보세요."
                />
              )}
              {nextCursor && (
                <button
                  className="secondary load-more"
                  disabled={loading}
                  onClick={() => loadPhotos(nextCursor!)}
                >
                  사진 더 보기
                </button>
              )}
            </>
          )}
          {page === "erp" && (
            <Erp
              key={user.id}
              user={user}
              googleClientId={boot?.googleClientId}
              onUser={setUser}
            />
          )}
          {page === "settings" && (
            <>
              <div className="page-heading">
                <div>
                  <span className="eyebrow">계정과 연결</span>
                  <h1>더보기</h1>
                  <p>업로드 진행 상태와 연결된 업무를 확인하세요.</p>
                </div>
              </div>
              <section className="panel account-panel">
                <span className="avatar large">{user.name.slice(0, 1)}</span>
                <div>
                  <h2>{user.name}</h2>
                  <p>{user.email}</p>
                </div>
                <button className="secondary" onClick={logout} disabled={busy}>
                  로그아웃
                </button>
              </section>
              <section className="panel">
                <div className="section-heading">
                  <h2>
                    업로드 대기 <span className="count">{pending}</span>
                  </h2>
                  <button
                    className="text-btn"
                    onClick={() => {
                      void retryQueue();
                      if (window.HangyeolBridge)
                        void nativeRequest("uploads.retry").then(() =>
                          refreshQueue(),
                        );
                    }}
                  >
                    다시 시도
                  </button>
                </div>
                {!pending && (
                  <p className="muted">대기 중인 사진이 없습니다.</p>
                )}
                {drafts.map((d) => (
                  <div className="queue-row" key={d.id}>
                    <div>
                      <b>{d.fileName}</b>
                      <span>
                        {d.metadata.farmName || "농가 미입력"} ·{" "}
                        {d.state === "uploading"
                          ? "전송 중 또는 복구 대기"
                          : d.state === "failed"
                            ? "재시도 필요"
                            : "전송 대기"}
                      </span>
                      {d.error && (
                        <small className="error-text">{d.error}</small>
                      )}
                    </div>
                    <button
                      className="text-btn"
                      onClick={async () => {
                        await deleteDraft(d.id);
                        await refreshQueue();
                      }}
                    >
                      기기에서 삭제
                    </button>
                  </div>
                ))}
                {nativeUploads
                  .filter((u) => u.state !== "complete")
                  .map((u) => (
                    <div className="queue-row" key={u.id}>
                      <div>
                        <b>{u.fileName}</b>
                        <span>{u.state}</span>
                        {u.error && (
                          <small className="error-text">{u.error}</small>
                        )}
                      </div>
                    </div>
                  ))}
              </section>
              <section className="panel">
                <h2>업무 연결</h2>
                <div className="integration-row">
                  <span>Google Sheets 사진 관리대장</span>
                  <span
                    className={
                      "pill " + (boot?.features.sheets ? "" : "neutral")
                    }
                  >
                    {boot?.features.sheets ? "설정됨" : "연결 전"}
                  </span>
                </div>
                <div className="integration-row">
                  <span>Discord 사진 알림</span>
                  <span
                    className={
                      "pill " + (boot?.features.discord ? "" : "neutral")
                    }
                  >
                    {boot?.features.discord ? "설정됨" : "연결 전"}
                  </span>
                </div>
                <p className="small muted">
                  연결 전에도 사진 등록과 앨범 조회는 이용할 수 있습니다.
                </p>
              </section>
              {jobs.length > 0 && (
                <section className="panel">
                  <div className="section-heading">
                    <h2>최근 연동 작업</h2>
                    <button className="text-btn" onClick={loadJobs}>
                      ↻ 새로고침
                    </button>
                  </div>
                  {jobs.slice(0, 20).map((j) => (
                    <div className="queue-row" key={j.id}>
                      <div>
                        <b>
                          {j.type === "sheets"
                            ? "사진 관리대장 반영"
                            : "Discord 알림"}
                        </b>
                        <span>
                          {j.message ||
                            (j.status === "done" ? "완료" : "처리 대기")}
                        </span>
                      </div>
                      <span
                        className={
                          "pill " + (j.status === "done" ? "" : "neutral")
                        }
                      >
                        {
                          {
                            done: "완료",
                            blocked: "연결 대기",
                            pending: "대기",
                            failed: "실패",
                          }[j.status]
                        }
                      </span>
                    </div>
                  ))}
                </section>
              )}
            </>
          )}
        </div>
        <footer className="page-footer">
          한결씨드 · 현장의 기록을 연결합니다
        </footer>
      </main>
      <nav className="bottom-nav" aria-label="모바일 주 메뉴">
        {(Object.keys(names) as Page[]).map((item) => (
          <button
            key={item}
            className={page === item ? "active" : ""}
            onClick={() => setPage(item)}
          >
            <span aria-hidden="true">{icons[item]}</span>
            {names[item]}
          </button>
        ))}
      </nav>
      <input
        ref={pickRef}
        hidden
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={filePicked}
      />
      <input
        ref={cameraRef}
        hidden
        type="file"
        accept="image/jpeg,image/png,image/webp"
        capture="environment"
        onChange={filePicked}
      />
      {(selected || edit) && (
        <PhotoForm
          file={selected}
          photo={edit}
          busy={busy}
          onSave={savePhoto}
          onClose={() => {
            if (!busy) {
              setSelected(null);
              setEdit(null);
            }
          }}
        />
      )}{" "}
      {detail && !edit && (
        <PhotoDetail
          photo={detail}
          onClose={() => setDetail(null)}
          onEdit={() => setEdit(detail)}
        />
      )}{" "}
      {toast && (
        <div className="toast" role="status">
          {toast}
          <button aria-label="알림 닫기" onClick={() => setToast("")}>
            ×
          </button>
        </div>
      )}
    </div>
  );
}
function Brand() {
  return (
    <div className="brand">
      <span className="brand-symbol" aria-hidden="true">
        h<span>•</span>
      </span>
      <span>
        한결씨드<small>WORKSPACE</small>
      </span>
    </div>
  );
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}
function Notice({
  children,
  close,
}: {
  children: ReactNode;
  close?: () => void;
}) {
  return (
    <div className="notice error" role="alert">
      {children}
      {close && (
        <button aria-label="오류 닫기" onClick={close}>
          ×
        </button>
      )}
    </div>
  );
}
function Empty({
  title,
  text,
  action,
}: {
  title: string;
  text: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty">
      <span aria-hidden="true">▧</span>
      <h3>{title}</h3>
      <p>{text}</p>
      {action}
    </div>
  );
}
function PhotoGrid({
  photos,
  onSelect,
}: {
  photos: Photo[];
  onSelect(photo: Photo): void;
}) {
  return (
    <div className="photo-grid">
      {photos.map((p) => (
        <button className="photo-card" key={p.id} onClick={() => onSelect(p)}>
          <div className="photo-image">
            <img
              src={p.imageUrl}
              alt={p.farmName ? p.farmName + " 작황 사진" : "작황 사진"}
              loading="lazy"
            />
            {p.status === "needs_info" && (
              <span className="photo-status">정보 보완</span>
            )}
          </div>
          <div className="photo-info">
            <span className="photo-date">{dateLabel(p.capturedAt)}</span>
            <h3>{p.farmName || "농가를 입력해 주세요"}</h3>
            <p>
              {[p.crop, p.variety].filter(Boolean).join(" · ") ||
                "작물 정보 미입력"}
            </p>
            <small>{p.address || "주소 미입력"}</small>
            <span className="photo-number">{p.number}</span>
          </div>
        </button>
      ))}
    </div>
  );
}
function PhotoDetail({
  photo,
  onClose,
  onEdit,
}: {
  photo: Photo;
  onClose(): void;
  onEdit(): void;
}) {
  return (
    <Dialog title="사진 상세" onClose={onClose}>
      <img
        className="detail-image"
        src={photo.imageUrl}
        alt={photo.farmName || "작황 사진"}
      />
      <div className="detail-title">
        <span className="eyebrow">{photo.number}</span>
        <h2>{photo.farmName || "농가 미입력"}</h2>
        <p>
          {[photo.crop, photo.variety].filter(Boolean).join(" · ") ||
            "작물 정보 미입력"}
        </p>
      </div>
      <dl className="detail-list">
        <div>
          <dt>촬영일</dt>
          <dd>{dateLabel(photo.capturedAt)}</dd>
        </div>
        <div>
          <dt>주소</dt>
          <dd>{photo.address || "미입력"}</dd>
        </div>
        <div>
          <dt>메모</dt>
          <dd>{photo.memo || "미입력"}</dd>
        </div>
        <div>
          <dt>등록일</dt>
          <dd>{dateLabel(photo.createdAt)}</dd>
        </div>
        <div>
          <dt>등록 경로</dt>
          <dd>{photo.source === "discord" ? "Discord" : "앱"}</dd>
        </div>
      </dl>
      <div className="dialog-actions">
        <button className="secondary" onClick={onClose}>
          닫기
        </button>
        <button className="primary" onClick={onEdit}>
          정보 수정
        </button>
      </div>
    </Dialog>
  );
}
function Dialog({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose(): void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    d?.showModal();
    return () => d?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className="dialog"
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
    >
      <div className="dialog-header">
        <h2>{title}</h2>
        <button className="icon-btn" aria-label="창 닫기" onClick={onClose}>
          ×
        </button>
      </div>
      {children}
    </dialog>
  );
}
function PhotoForm({
  file,
  photo,
  busy,
  onSave,
  onClose,
}: {
  file: File | Asset | null;
  photo: Photo | null;
  busy: boolean;
  onSave(metadata: PhotoMetadata): Promise<void>;
  onClose(): void;
}) {
  const [meta, setMeta] = useState<PhotoMetadata>(
      photo ? { ...photo } : blankMetadata(),
    ),
    [error, setError] = useState(""),
    [extracting, setExtracting] = useState(false),
    [preview, setPreview] = useState("");
  const touched = useRef(false);
  useEffect(() => {
    if (!file) return;
    if (!(file instanceof File)) {
      setMeta((m) => ({
        ...m,
        capturedAt: file.capturedAt || null,
        capturedAtSource: file.capturedAtSource || "unknown",
      }));
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    let active = true;
    setExtracting(true);
    void exifr
      .parse(file, ["DateTimeOriginal", "latitude", "longitude"])
      .then((data) => {
        if (!active || touched.current || !data) return;
        setMeta((m) => ({
          ...m,
          capturedAt:
            data.DateTimeOriginal instanceof Date
              ? data.DateTimeOriginal.toISOString()
              : null,
          capturedAtSource: data.DateTimeOriginal ? "exif" : "unknown",
          latitude: data.latitude ?? null,
          longitude: data.longitude ?? null,
          locationSource:
            data.latitude != null && data.longitude != null
              ? "exif"
              : "unknown",
        }));
      })
      .catch(() => {})
      .finally(() => {
        if (active) setExtracting(false);
      });
    return () => {
      active = false;
      URL.revokeObjectURL(url);
    };
  }, [file]);
  function update(key: keyof PhotoMetadata, value: unknown) {
    touched.current = true;
    setMeta((m) => ({ ...m, [key]: value }));
  }
  async function submit(e: FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await onSave(meta);
    } catch (e) {
      setError(errorMessage(e));
    }
  }
  async function locate() {
    if (
      !confirm(
        "현재 기기의 위치를 이 사진의 위치로 사용하시겠습니까? 예전에 찍은 사진에는 사용하지 마세요.",
      )
    )
      return;
    try {
      const coords = window.HangyeolBridge
        ? await nativeRequest<{ latitude: number; longitude: number }>(
            "location.request",
          )
        : await new Promise<GeolocationCoordinates>((resolve, reject) =>
            navigator.geolocation
              ? navigator.geolocation.getCurrentPosition(
                  (p) => resolve(p.coords),
                  reject,
                  { timeout: 15000 },
                )
              : reject(new Error("위치 기능을 사용할 수 없습니다.")),
          );
      touched.current = true;
      setMeta((m) => ({
        ...m,
        latitude: coords.latitude,
        longitude: coords.longitude,
        locationSource: "device",
      }));
    } catch (e) {
      setError("위치를 가져오지 못했습니다. 주소를 직접 입력해 주세요.");
    }
  }
  return (
    <Dialog title={photo ? "사진 정보 수정" : "새 작황 사진"} onClose={onClose}>
      <form onSubmit={submit}>
        {error && <Notice>{error}</Notice>}
        {preview && (
          <img
            className="form-preview"
            src={preview}
            alt="등록할 사진 미리보기"
          />
        )}
        {file && !(file instanceof File) && (
          <div className="native-file">
            ▧ {file.fileName}
            <small>선택한 사진은 앱에서 안전하게 업로드합니다.</small>
          </div>
        )}
        <div className="form-grid">
          <Field label="농가명">
            <input
              autoFocus
              value={meta.farmName}
              maxLength={100}
              placeholder="예: 한결농장"
              onChange={(e) => update("farmName", e.target.value)}
            />
          </Field>
          <Field label="촬영일시 (한국 시간)">
            <input
              type="datetime-local"
              value={dateInput(meta.capturedAt)}
              onChange={(e) => {
                touched.current = true;
                setMeta((m) => ({
                  ...m,
                  capturedAt: e.target.value
                    ? new Date(e.target.value + "+09:00").toISOString()
                    : null,
                  capturedAtSource: e.target.value ? "manual" : "unknown",
                }));
              }}
            />
          </Field>
          <Field label="작물">
            <input
              value={meta.crop}
              maxLength={100}
              placeholder="예: 토마토"
              onChange={(e) => update("crop", e.target.value)}
            />
          </Field>
          <Field label="품종">
            <input
              value={meta.variety}
              maxLength={100}
              placeholder="품종명"
              onChange={(e) => update("variety", e.target.value)}
            />
          </Field>
        </div>
        <p className="small muted metadata-note">
          {extracting
            ? "사진의 촬영 정보를 읽고 있습니다…"
            : meta.capturedAtSource === "exif"
              ? "사진에서 촬영일시를 불러왔습니다. 확인 후 수정할 수 있습니다."
              : "촬영일을 모르면 비워 두세요. 등록일과 구분해 보관합니다."}
        </p>
        <Field label="촬영 주소">
          <input
            value={meta.address}
            maxLength={300}
            placeholder="촬영한 장소의 주소를 입력해 주세요"
            onChange={(e) => update("address", e.target.value)}
          />
        </Field>
        <div className="location-line">
          <span className="small muted">
            {meta.latitude != null && meta.longitude != null
              ? `좌표 ${meta.latitude.toFixed(5)}, ${meta.longitude.toFixed(5)} · ${meta.locationSource === "exif" ? "사진 정보" : "직접 지정"}`
              : "위치 정보 없음 · 주소를 직접 입력할 수 있습니다"}
          </span>
          <button type="button" className="text-btn" onClick={locate}>
            현재 위치 지정
          </button>
        </div>
        <Field label="메모">
          <textarea
            rows={3}
            value={meta.memo}
            maxLength={4000}
            placeholder="작황이나 현장에서 확인한 내용을 적어 주세요"
            onChange={(e) => update("memo", e.target.value)}
          />
        </Field>
        <p className="small muted">
          농가명이나 작물 정보가 없는 사진은 ‘정보 보완 필요’로 모입니다.
        </p>
        <div className="dialog-actions">
          <button
            type="button"
            className="secondary"
            onClick={onClose}
            disabled={busy}
          >
            취소
          </button>
          <button
            type="submit"
            className="primary"
            disabled={busy || extracting}
          >
            {busy
              ? "저장 중…"
              : photo
                ? "수정 저장"
                : navigator.onLine
                  ? "사진 등록"
                  : "기기에 저장"}
          </button>
        </div>
      </form>
    </Dialog>
  );
}
