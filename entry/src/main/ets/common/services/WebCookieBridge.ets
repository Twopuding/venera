import { webview } from '@kit.ArkWeb';
import { JsCookieStore, JsCookieEntry } from './JsCookieStore';

/**
 * ArkWeb Cookie ↔ JsCookieStore 同步（API 23 @kit.ArkWeb）。
 * 漫画源 WebView 登录后写入，供 init.js Network.getCookies 使用。
 */
export class WebCookieBridge {
  /** 将 Web 组件 Cookie 同步到 JsCookieStore（按页面 URL 键） */
  static syncFromWeb(url: string): void {
    if (url.length === 0) {
      return;
    }
    try {
      const raw = webview.WebCookieManager.fetchCookieSync(url);
      if (!raw || raw.length === 0) {
        return;
      }
      const entries = WebCookieBridge.parseCookieHeader(raw, url);
      if (entries.length > 0) {
        JsCookieStore.getInstance().setCookies(url, entries);
        console.info(`[WebCookieBridge] synced ${entries.length} cookies for ${url}`);
      }
    } catch (e) {
      console.warn(`[WebCookieBridge] syncFromWeb failed: ${e}`);
    }
  }

  /** 将 JsCookieStore 中已有 Cookie 写入 ArkWeb（打开登录页前） */
  static applyToWeb(url: string): void {
    const stored = JsCookieStore.getInstance().getCookies(url);
    for (let i = 0; i < stored.length; i++) {
      const c = stored[i];
      if (c.name.length === 0) {
        continue;
      }
      const line = `${c.name}=${c.value}`;
      try {
        webview.WebCookieManager.configCookieSync(url, line);
      } catch (e) {
        console.warn(`[WebCookieBridge] configCookie failed: ${e}`);
      }
    }
  }

  static clearWebCookies(): void {
    try {
      webview.WebCookieManager.deleteEntireCookie();
    } catch (e) {
      console.warn(`[WebCookieBridge] clear failed: ${e}`);
    }
  }

  private static parseCookieHeader(header: string, pageUrl: string): JsCookieEntry[] {
    const out: JsCookieEntry[] = [];
    const parts = header.split(';');
    let host = '';
    const m = pageUrl.match(/^https?:\/\/([^/?#]+)/i);
    if (m && m[1]) {
      host = m[1];
    }
    for (let i = 0; i < parts.length; i++) {
      const seg = parts[i].trim();
      if (seg.length === 0) {
        continue;
      }
      const eq = seg.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name = seg.substring(0, eq).trim();
      const value = seg.substring(eq + 1).trim();
      if (name.length === 0) {
        continue;
      }
      const entry: JsCookieEntry = { name: name, value: value };
      if (host.length > 0) {
        entry.domain = host;
      }
      entry.path = '/';
      out.push(entry);
    }
    return out;
  }
}
