/* Whisky Collector — Service Worker
   앱 셸: stale-while-revalidate / 외부 병 사진: cache-first(런타임 캐시) */
const V = 'wc-shell-v2';
const IMG = 'wc-img-v2';    // 일반 표시용 (no-cors, opaque 허용)
const IMGC = 'wc-imgc-v2';  // CORS 요청용 — 캔버스 정규화에 쓰이므로 opaque를 섞으면 안 됨
const SHELL = [
  './', './index.html', './kb.js', './manifest.webmanifest', './whisky.json',
  './icons/icon-192.png', './icons/icon-512.png',
  './icons/icon-maskable-512.png', './icons/apple-touch-icon.png', './icons/favicon-64.png',
];

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(V);
    // 개별 실패가 전체 설치를 막지 않도록 하나씩 추가
    await Promise.all(SHELL.map(u => c.add(new Request(u, {cache: 'reload'})).catch(() => {})));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keep = [V, IMG, IMGC];
    for (const k of await caches.keys()) if (!keep.includes(k)) await caches.delete(k);
    await self.clients.claim();
  })());
});

self.addEventListener('message', e => { if (e.data === 'skipWaiting') self.skipWaiting(); });

/* 코드·셸은 반드시 서버와 재검증한다.
   그냥 fetch(req) 하면 브라우저 HTTP 캐시(GitHub Pages는 max-age=600)를 재사용해
   배포 직후에도 옛 파일이 돌아온다. no-cache는 304로 값싸게 확인만 한다. */
const revalidate = url => fetch(url, {cache: 'no-cache', credentials: 'same-origin'});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const sameOrigin = url.origin === location.origin;

  // 앱 진입(내비게이션): 서버 재검증 우선, 실패 시 캐시된 셸
  if (req.mode === 'navigate') {
    e.respondWith((async () => {
      try {
        const res = await revalidate(req.url);
        if (res && res.ok) (await caches.open(V)).put('./index.html', res.clone()).catch(() => {});
        return res;
      } catch {
        return (await caches.match('./index.html')) || (await caches.match('./')) || Response.error();
      }
    })());
    return;
  }

  // 외부 병 사진: 캐시 우선 → 없으면 받아서 캐시(오프라인에서도 보이도록)
  if (!sameOrigin) {
    if (req.destination !== 'image') return;
    e.respondWith((async () => {
      // 요청 모드를 그대로 유지해야 crossOrigin="anonymous" 이미지가 캔버스에서 읽힌다.
      const c = await caches.open(req.mode === 'cors' ? IMGC : IMG);
      const hit = await c.match(req);
      if (hit) return hit;
      try {
        const res = await fetch(req);
        if (res && (res.ok || res.type === 'opaque')) c.put(req, res.clone()).catch(() => {});
        return res;
      } catch { return new Response('', {status: 504, statusText: 'offline'}); }
    })());
    return;
  }

  // 코드·데이터(js/json/webmanifest)는 네트워크 우선.
  // 캐시 우선으로 두면 새 index.html + 구버전 kb.js 가 섞여 앱이 깨진다.
  if (/\.(js|json|webmanifest|html)$/i.test(url.pathname)) {
    e.respondWith((async () => {
      const c = await caches.open(V);
      try {
        const res = await revalidate(req.url);
        if (res && res.ok) c.put(req, res.clone()).catch(() => {});
        return res;
      } catch {
        return (await c.match(req, {ignoreSearch: true})) || new Response('', {status: 504});
      }
    })());
    return;
  }

  // 그 외 동일 출처 자원(아이콘 등): 캐시 즉시 응답 + 백그라운드 갱신
  e.respondWith((async () => {
    const c = await caches.open(V);
    const hit = await c.match(req, {ignoreSearch: true});
    const net = fetch(req).then(res => {
      if (res && res.ok) c.put(req, res.clone()).catch(() => {});
      return res;
    }).catch(() => null);
    return hit || (await net) || new Response('', {status: 504});
  })());
});
