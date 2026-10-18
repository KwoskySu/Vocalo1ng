const passport = 'https://passport.bilibili.com';
const api = 'https://api.bilibili.com';
const allowedCookies = new Set(['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5', 'sid', 'buvid3', 'buvid4', 'b_nut', 'b_lsid', '_uuid']);
export const biliUserAgent = 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

export function biliCookieHeader(cookies = {}) {
  return Object.entries(cookies).filter(([key]) => allowedCookies.has(key))
    .map(([key, value]) => `${key}=${value}`).join('; ');
}

export class BilibiliAuth {
  constructor({ fetcher = fetch, now = Date.now } = {}) { this.fetcher = fetcher; this.now = now; }
  async ensureBrowser(state) {
    if (state.browserReady && this.now() - state.browserReady < 3600_000) return;
    if (state.browserPending) return state.browserPending;
    state.browserPending = (async () => {
      const response = await this.fetcher('https://www.bilibili.com/', {headers:{'User-Agent':biliUserAgent}, redirect:'error', signal:AbortSignal.timeout(12000)});
      await response.body?.cancel();
      if (!response.ok) return;
      state.cookies ??= {};
      for (const line of response.headers.getSetCookie()) {
        const first = line.split(';')[0], split = first.indexOf('=');
        const name = first.slice(0,split);
        if (['buvid3','buvid4','b_nut','b_lsid','_uuid'].includes(name) && !state.cookies[name]) state.cookies[name] = first.slice(split+1);
      }
      state.browserReady = this.now();
    })().finally(()=>delete state.browserPending);
    return state.browserPending;
  }
  async json(url, cookies = {}) {
    const response = await this.fetcher(url, { headers: {
      'User-Agent': biliUserAgent, Referer: 'https://www.bilibili.com/',
      ...(biliCookieHeader(cookies) ? { Cookie: biliCookieHeader(cookies) } : {}),
    }, redirect: 'error', signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error('B 站服务暂时不可用，请稍后重试');
    const body = await response.json();
    if (body.code !== 0) throw new Error('B 站暂时无法处理登录请求，请稍后重试');
    return { data: body.data, headers: response.headers };
  }
  async generate(state) {
    const pending = {};
    state.pending = pending;
    const { data } = await this.json(`${passport}/x/passport-login/web/qrcode/generate`);
    if (state.pending !== pending) throw new Error('登录二维码已更新，请重新刷新');
    const url = new URL(data?.url);
    if (url.protocol !== 'https:' || !['passport.bilibili.com', 'account.bilibili.com'].includes(url.hostname) || !data.qrcode_key) {
      throw new Error('无法生成 B 站登录二维码');
    }
    state.key = data.qrcode_key; state.created = this.now();
    return { url: url.href };
  }
  async profile(cookies) {
    const { data } = await this.json(`${api}/x/web-interface/nav`, cookies);
    if (!data?.isLogin || !data.mid) throw new Error('B 站会话未生效，请重新扫码');
    return { uid: String(data.mid), nickname: data.uname, avatar: data.face,
      vip: data.vipStatus === 1 };
  }
  async check(state) {
    if (!state.key || this.now() - state.created >= 180000) return { code: 86038 };
    const key = state.key;
    const query = new URLSearchParams({ qrcode_key: key });
    const { data, headers } = await this.json(`${passport}/x/passport-login/web/qrcode/poll?${query}`);
    if (state.key !== key) return { code: 86038 };
    if (data.code !== 0) {
      if (data.code === 86038) delete state.key;
      return { code: data.code };
    }
    const cookies = {...state.cookies};
    for (const item of headers.getSetCookie()) {
      const first = item.split(';')[0]; const split = first.indexOf('=');
      if (split > 0 && allowedCookies.has(first.slice(0, split))) cookies[first.slice(0, split)] = first.slice(split + 1);
    }
    // Some platform responses carry credentials only in the SSO return URL.
    // Parse that URL locally; never navigate to it or return it to the frontend.
    if (data.url) {
      const sso = new URL(data.url);
      if (sso.protocol === 'https:' && ['passport.biligame.com', 'passport.bilibili.com'].includes(sso.hostname)) {
        for (const key of allowedCookies) {
          const value = sso.searchParams.get(key);
          if (!cookies[key] && value) cookies[key] = encodeURIComponent(value);
        }
      }
    }
    if (!cookies.SESSDATA) throw new Error('B 站未返回有效登录会话，请重新扫码');
    const profile = await this.profile(cookies);
    if (state.key !== key) return { code: 86038 };
    state.cookies = cookies; state.profile = profile; delete state.key;
    return { code: 0, profile };
  }
  logout(state) {
    for (const key of Object.keys(state)) delete state[key];
    return { ok: true };
  }
}
