/* coi-serviceworker v0.1.7 - Guido Zuidhof and contributors, licensed under MIT
 * https://github.com/gzuidhof/coi-serviceworker
 *
 * Adds Cross-Origin-Opener-Policy: same-origin and Cross-Origin-Embedder-Policy: require-corp
 * headers to all responses, enabling SharedArrayBuffer (required for ffmpeg.wasm threading).
 * Necessary when the host (e.g. GitHub Pages) cannot set HTTP headers directly.
 */
if (typeof window === "undefined") {
  // ---- Service Worker context ----
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

  async function handleFetch(request) {
    if (request.cache === "only-if-cached" && request.mode !== "same-origin") {
      return;
    }
    const r = await fetch(request);
    if (r.status === 0) {
      return r;
    }
    const newHeaders = new Headers(r.headers);
    newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
    newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
    return new Response(r.body, {
      status: r.status,
      statusText: r.statusText,
      headers: newHeaders,
    });
  }

  self.addEventListener("fetch", (event) => {
    event.respondWith(handleFetch(event.request));
  });
} else {
  // ---- Page context ----
  // If already cross-origin isolated, nothing to do.
  if (crossOriginIsolated) return;

  let reloading = false;

  navigator.serviceWorker
    .register(window.document.currentScript.src)
    .then((reg) => {
      // If a new SW is installing, wait for it to activate then reload.
      function awaitInstall(sw) {
        sw.addEventListener("statechange", () => {
          if (sw.state === "activated") {
            if (!reloading) {
              reloading = true;
              window.location.reload();
            }
          }
        });
      }
      if (reg.installing) {
        awaitInstall(reg.installing);
      } else if (reg.waiting) {
        awaitInstall(reg.waiting);
      } else if (reg.active) {
        // SW already active but page wasn't isolated — reload once.
        if (!reloading) {
          reloading = true;
          window.location.reload();
        }
      }
      reg.addEventListener("updatefound", () => {
        if (reg.installing) awaitInstall(reg.installing);
      });
    })
    .catch((err) => console.error("coi-serviceworker registration failed:", err));
}
