import { util } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import { HttpService, HttpResponse } from './HttpService';
import { ComicSourceDataService } from './ComicSourceDataService';
import { JsCookieStore, JsCookieEntry } from './JsCookieStore';
import { JsConvertUtil, JsConvertRequest } from '../utils/JsConvertUtil';

/** init.js sendMessage 载荷（与上游 js_engine.dart 对齐的子集） */
export interface JsMessagePayload {
  method?: string;
  key?: string;
  data_key?: string;
  setting_key?: string;
  data?: Object;
  url?: string;
  http_method?: string;
  headers?: Record<string, string>;
  data_body?: string;
  bytes?: boolean;
  time?: number;
  type?: string;
  value?: string | ArrayBuffer;
  hash?: string;
  isEncode?: boolean;
  isString?: boolean;
  level?: string;
  title?: string;
  content?: string;
  min?: number;
  max?: number;
  function?: string;
  cookies?: Object[];
  text?: string;
  args?: Object[];
}

/** init.js http 消息返回结构（对齐上游 js_engine _http） */
export interface JsHttpResult {
  status: number;
  headers: Record<string, string>;
  body: string | ArrayBuffer | undefined;
  error?: string;
}

/**
 * QuickJS sendMessage 宿主实现（API 23）。
 * 供 JsEngineBridge / 后续 Worker-NAPI 调用；覆盖漫画源脚本最常用的消息类型。
 */
export class JsMessageHost {
  private static instance: JsMessageHost;

  static getInstance(): JsMessageHost {
    if (!JsMessageHost.instance) {
      JsMessageHost.instance = new JsMessageHost();
    }
    return JsMessageHost.instance;
  }

  /** QuickJS NAPI 同步回调（不含 http，http 走原生 RCP） */
  handleSync(message: JsMessagePayload): Object | null {
    const method = message.method ?? '';
    if (method === 'http') {
      return null;
    }
    switch (method) {
      case 'delay':
        return null;
      case 'convert': {
        const sync = JsConvertUtil.handleSync(this.toConvertRequest(message));
        if (sync !== null) {
          return sync;
        }
        return null;
      }
      case 'load_data':
        return ComicSourceDataService.getInstance().loadData(message.key ?? '', message.data_key ?? '');
      case 'load_setting':
        return ComicSourceDataService.getInstance().loadSetting(message.key ?? '', message.setting_key ?? '');
      case 'save_data':
        ComicSourceDataService.getInstance().saveData(message.key ?? '', message.data_key ?? '', message.data);
        return null;
      case 'delete_data':
        ComicSourceDataService.getInstance().deleteData(message.key ?? '', message.data_key ?? '');
        return null;
      case 'isLogged':
        return ComicSourceDataService.getInstance().isLogged(message.key ?? '');
      case 'cookie':
        return this.handleCookie(message);
      case 'uuid':
        return util.generateRandomUUID(false);
      case 'random':
        return this.handleRandom(message.min ?? 0, message.max ?? 1);
      case 'log':
        this.handleLog(message);
        return null;
      case 'getPlatform':
        return 'harmonyos';
      case 'getLocale':
        return 'zh_CN';
      default:
        return null;
    }
  }

  async handle(message: JsMessagePayload): Promise<Object | null> {
    const method = message.method ?? '';
    switch (method) {
      case 'http':
        return await this.handleHttp(message);
      case 'delay':
        return await this.handleDelay(message.time ?? 0);
      case 'convert':
        return await JsConvertUtil.handle(this.toConvertRequest(message));
      case 'load_data':
        return ComicSourceDataService.getInstance().loadData(message.key ?? '', message.data_key ?? '');
      case 'load_setting':
        return ComicSourceDataService.getInstance().loadSetting(message.key ?? '', message.setting_key ?? '');
      case 'save_data':
        ComicSourceDataService.getInstance().saveData(message.key ?? '', message.data_key ?? '', message.data);
        return null;
      case 'delete_data':
        ComicSourceDataService.getInstance().deleteData(message.key ?? '', message.data_key ?? '');
        return null;
      case 'isLogged':
        return ComicSourceDataService.getInstance().isLogged(message.key ?? '');
      case 'cookie':
        return this.handleCookie(message);
      case 'uuid':
        return util.generateRandomUUID(false);
      case 'random':
        return this.handleRandom(message.min ?? 0, message.max ?? 1);
      case 'log':
        this.handleLog(message);
        return null;
      case 'getPlatform':
        return 'harmonyos';
      case 'getLocale':
        return 'zh_CN';
      case 'setClipboard':
        return await this.setClipboard(message.text ?? '');
      case 'getClipboard':
        return await this.getClipboard();
      case 'html':
      case 'image':
      case 'UI':
      case 'compute':
        console.warn(`[JsMessageHost] ${method} stub — awaiting QuickJS/UI bridge`);
        return null;
      default:
        console.warn(`[JsMessageHost] unhandled method: ${method}`);
        return null;
    }
  }

  /** 显式构造 convert 请求，避免 JsMessagePayload → JsConvertRequest 结构性赋值 */
  private toConvertRequest(message: JsMessagePayload): JsConvertRequest {
    const req: JsConvertRequest = {
      type: message.type,
      isEncode: message.isEncode,
      isString: message.isString,
      value: message.value,
      hash: message.hash
    };
    if (message.key !== undefined) {
      req.key = message.key;
    }
    return req;
  }

  private async handleHttp(message: JsMessagePayload): Promise<JsHttpResult> {
    const headers: Record<string, string> = {};
    if (message.headers) {
      const keys = Object.keys(message.headers);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        headers[k] = message.headers[k];
      }
    }
    if (!headers['User-Agent'] && !headers['user-agent']) {
      headers['User-Agent'] = 'Venera-HarmonyOS/1.0';
    }
    try {
      const res: HttpResponse = await HttpService.getInstance().request({
        url: message.url ?? '',
        method: message.http_method ?? 'GET',
        headers: headers,
        body: message.data_body,
        bytes: message.bytes === true
      });
      const ok: JsHttpResult = {
        status: res.status,
        headers: res.headers,
        body: res.body
      };
      return ok;
    } catch (e) {
      const fail: JsHttpResult = {
        status: 0,
        headers: {},
        body: undefined,
        error: `${e}`
      };
      return fail;
    }
  }

  private handleCookie(message: JsMessagePayload): JsCookieEntry[] | null {
    const fn = message.function ?? '';
    const url = message.url ?? '';
    const store = JsCookieStore.getInstance();
    if (fn === 'set') {
      const parsed = this.parseCookies(message.cookies);
      store.setCookies(url, parsed);
      return null;
    }
    if (fn === 'get') {
      return store.getCookies(url);
    }
    if (fn === 'delete') {
      store.deleteCookies(url);
      return null;
    }
    return null;
  }

  private parseCookies(raw: Object[] | undefined): JsCookieEntry[] {
    if (!raw) {
      return [];
    }
    const out: JsCookieEntry[] = [];
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i] as Record<string, string>;
      const entry: JsCookieEntry = {
        name: item['name'] ?? '',
        value: item['value'] ?? ''
      };
      if (item['domain']) {
        entry.domain = item['domain'];
      }
      if (item['path']) {
        entry.path = item['path'];
      }
      out.push(entry);
    }
    return out;
  }

  private async handleDelay(ms: number): Promise<null> {
    if (ms <= 0) {
      return null;
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
    return null;
  }

  private handleRandom(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }

  private handleLog(message: JsMessagePayload): void {
    const tag = message.title ?? 'JS';
    const text = message.content ?? '';
    const level = message.level ?? 'info';
    if (level === 'error') {
      console.error(`[${tag}] ${text}`);
    } else if (level === 'warning') {
      console.warn(`[${tag}] ${text}`);
    } else {
      console.info(`[${tag}] ${text}`);
    }
  }

  private async setClipboard(text: string): Promise<null> {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const sysBoard = pasteboard.getSystemPasteboard();
    await sysBoard.setData(data);
    return null;
  }

  private async getClipboard(): Promise<string> {
    const sysBoard = pasteboard.getSystemPasteboard();
    const data = await sysBoard.getData();
    const text = data.getPrimaryText();
    return text ?? '';
  }
}
