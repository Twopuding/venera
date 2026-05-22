import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppDataService } from './AppDataService';

const DEFAULT_HEADERS: Record<string, string> = {
  'User-Agent': 'Venera-HarmonyOS/1.0'
};

export interface HttpRequestOptions {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  bytes?: boolean;
}

export interface HttpResponse {
  status: number;
  headers: Record<string, string>;
  body: string | ArrayBuffer | undefined;
}

/**
 * HTTP client — replaces upstream Dio + rhttp for HarmonyOS network stack (API 23).
 */
export class HttpService {
  private static instance: HttpService;

  static getInstance(): HttpService {
    if (!HttpService.instance) {
      HttpService.instance = new HttpService();
    }
    return HttpService.instance;
  }

  async get(url: string, headers?: Record<string, string>): Promise<string> {
    const res = await this.request({
      url: url,
      method: 'GET',
      headers: headers,
      bytes: false
    });
    return typeof res.body === 'string' ? res.body : '';
  }

  async request(options: HttpRequestOptions): Promise<HttpResponse> {
    const proxy = AppDataService.getInstance().settings.proxy;
    const request = http.createHttp();
    const mergedHeaders: Record<string, string> = {};
    const defaults = Object.keys(DEFAULT_HEADERS);
    for (let i = 0; i < defaults.length; i++) {
      const k = defaults[i];
      mergedHeaders[k] = DEFAULT_HEADERS[k];
    }
    if (options.headers) {
      const keys = Object.keys(options.headers);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        mergedHeaders[k] = options.headers[k];
      }
    }
    const method = (options.method ?? 'GET').toUpperCase();
    const wantBytes = options.bytes === true;
    try {
      const response = await request.request(options.url, {
        method: method === 'POST' ? http.RequestMethod.POST :
          method === 'PUT' ? http.RequestMethod.PUT :
            method === 'DELETE' ? http.RequestMethod.DELETE :
              method === 'HEAD' ? http.RequestMethod.HEAD :
                http.RequestMethod.GET,
        header: mergedHeaders,
        extraData: options.body,
        expectDataType: wantBytes ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING,
        usingProxy: proxy.length > 0,
        caPath: ''
      });
      const headerMap: Record<string, string> = {};
      if (response.header) {
        const rawHeader = response.header as Record<string, string | number | string[]>;
        const keys = Object.keys(rawHeader);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const v: string | number | string[] = rawHeader[k];
          if (Array.isArray(v)) {
            headerMap[k] = v.join(',');
          } else {
            headerMap[k] = `${v}`;
          }
        }
      }
      return {
        status: response.responseCode,
        headers: headerMap,
        body: wantBytes ? (response.result as ArrayBuffer) : (response.result as string)
      };
    } finally {
      request.destroy();
    }
  }

  async downloadFile(url: string, destPath: string,
    onProgress?: (received: number, total: number) => void): Promise<void> {
    const res = await this.request({ url: url, method: 'GET', bytes: true });
    if (res.status < 200 || res.status >= 300) {
      throw new Error(`Download failed: ${res.status}`);
    }
    const buffer = res.body as ArrayBuffer;
    const slash = destPath.lastIndexOf('/');
    if (slash > 0) {
      const parent = destPath.substring(0, slash);
      try {
        fileIo.mkdirSync(parent, true);
      } catch (_e) {
        // may exist
      }
    }
    const file = fileIo.openSync(destPath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, buffer);
    fileIo.closeSync(file.fd);
    onProgress?.(buffer.byteLength, buffer.byteLength);
  }
}
