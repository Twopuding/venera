import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppConstants } from '../constants/AppConstants';

/** 漫画源 HTTP Cookie 条目（与 init.js Cookie 结构兼容的子集） */
export interface JsCookieEntry {
  name: string;
  value: string;
  domain?: string;
  path?: string;
}

/**
 * 按 URL 持久化 Cookie，供 init.js Network.setCookies / getCookies（API 23 沙箱）。
 */
export class JsCookieStore {
  private static instance: JsCookieStore;
  private storePath: string = '';
  private cache: Record<string, JsCookieEntry[]> = {};

  static getInstance(): JsCookieStore {
    if (!JsCookieStore.instance) {
      JsCookieStore.instance = new JsCookieStore();
    }
    return JsCookieStore.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.storePath = `${context.filesDir}/${AppConstants.COMIC_SOURCES_DIR}/cookies.json`;
    this.loadFromDisk();
  }

  private loadFromDisk(): void {
    try {
      const file = fileIo.openSync(this.storePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(this.storePath);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      const bytes = new Uint8Array(buf);
      let text = '';
      for (let i = 0; i < bytes.length; i++) {
        text += String.fromCharCode(bytes[i]);
      }
      this.cache = JSON.parse(text) as Record<string, JsCookieEntry[]>;
    } catch (_e) {
      this.cache = {};
    }
  }

  private persist(): void {
    if (this.storePath.length === 0) {
      return;
    }
    const text = JSON.stringify(this.cache);
    const bytes = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) {
      bytes[i] = text.charCodeAt(i) & 0xff;
    }
    const slash = this.storePath.lastIndexOf('/');
    if (slash > 0) {
      try {
        fileIo.mkdirSync(this.storePath.substring(0, slash), true);
      } catch (_e) {
        // exists
      }
    }
    const file = fileIo.openSync(this.storePath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, bytes.buffer);
    fileIo.closeSync(file.fd);
  }

  setCookies(url: string, cookies: JsCookieEntry[]): void {
    if (url.length === 0) {
      return;
    }
    this.cache[url] = cookies;
    this.persist();
  }

  getCookies(url: string): JsCookieEntry[] {
    return this.cache[url] ?? [];
  }

  deleteCookies(url: string): void {
    const copy: Record<string, JsCookieEntry[]> = {};
    const keys = Object.keys(this.cache);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k !== url) {
        copy[k] = this.cache[k];
      }
    }
    this.cache = copy;
    this.persist();
  }
}
