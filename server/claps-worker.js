// FolderAge — счётчик хлопков. Cloudflare Worker + KV (привязка CLAPS).
// GET  /claps            → {"total": N}
// POST /claps {id, n}    → {"total": N, "yours": M}   (с одного устройства — не больше 50 за всё время)
const MAX_PER_DEVICE = 50;
const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", ...extra } });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/claps") return json({ error: "not found" }, 404);

    if (request.method === "GET") {
      const total = parseInt((await env.CLAPS.get("total")) || "0", 10);
      return json({ total }, 200, { "cache-control": "public, max-age=300" });
    }

    if (request.method === "POST") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "bad json" }, 400); }
      const id = String(body.id || "");
      const n = Number(body.n);
      if (!/^[0-9a-fA-F-]{36}$/.test(id) || !Number.isInteger(n) || n < 1 || n > MAX_PER_DEVICE) {
        return json({ error: "bad request" }, 400);
      }
      const used = parseInt((await env.CLAPS.get("d:" + id)) || "0", 10);
      const add = Math.max(0, Math.min(n, MAX_PER_DEVICE - used));
      let total = parseInt((await env.CLAPS.get("total")) || "0", 10);
      if (add > 0) {
        total += add;
        await env.CLAPS.put("d:" + id, String(used + add));
        await env.CLAPS.put("total", String(total));
      }
      return json({ total, yours: used + add });
    }

    return json({ error: "method not allowed" }, 405);
  },
};
