// A media request may remain open while the viewer is paused or seeking.
// Limit the wait for headers, rather than aborting a healthy streaming body.
export async function fetchMedia(fetcher, target, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try { return await fetcher(target, { ...options, signal: controller.signal }); }
  finally { clearTimeout(timeout); }
}
