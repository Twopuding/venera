import { util } from '@kit.ArkTS';
import { HttpService } from '../services/HttpService';
import { JsImageService } from '../services/JsImageService';
import { JsNativeRuntime } from '../services/JsNativeRuntime';
import { ImageCacheUtil } from './ImageCacheUtil';

/** 对齐 init.js ImageLoadingConfig 的 JSON 形态 */
export interface ImageLoadingConfigLike {
  url?: string;
  method?: string;
  data?: string;
  headers?: Record<string, string>;
  onResponse?: string;
  modifyImage?: string;
  onLoadFailed?: ImageLoadingConfigLike;
}

/**
 * 将 comic.loadEp 返回的页项（URL 字符串或 ImageLoadingConfig）解析为本地可读路径。
 */
export class ComicImageResolver {
  private static maxFailDepth: number = 3;

  static async resolvePage(entry: Object | string): Promise<string> {
    if (typeof entry === 'string') {
      if (entry.length === 0) {
        return '';
      }
      if (ImageCacheUtil.isRemoteUrl(entry)) {
        return await ImageCacheUtil.ensureCached(entry);
      }
      return entry;
    }
    if (entry === null || typeof entry !== 'object') {
      return '';
    }
    const cfg = entry as ImageLoadingConfigLike;
    return await ComicImageResolver.resolveConfig(cfg, 0);
  }

  static async resolveAll(entries: Object[]): Promise<string[]> {
    const out: string[] = [];
    for (let i = 0; i < entries.length; i++) {
      out.push(await ComicImageResolver.resolvePage(entries[i]));
    }
    return out;
  }

  private static async resolveConfig(cfg: ImageLoadingConfigLike, depth: number): Promise<string> {
    const url = cfg.url ?? '';
    if (url.length === 0) {
      return '';
    }
    try {
      let body = await ComicImageResolver.fetchBody(cfg);
      body = await ComicImageResolver.applyOnResponse(cfg.onResponse, body);
      let imageKey = await JsImageService.getInstance().registerFromBytes(body);
      if (cfg.modifyImage && cfg.modifyImage.length > 0) {
        const outKey = await ComicImageResolver.runModifyImage(cfg.modifyImage, imageKey);
        JsImageService.getInstance().release(imageKey);
        if (outKey === null) {
          throw new Error('modifyImage returned null');
        }
        imageKey = outKey;
      }
      const cachePath = `${ImageCacheUtil.getCacheDir()}/puzzle_${imageKey}_${Date.now()}.jpg`;
      await JsImageService.getInstance().exportToFile(imageKey, cachePath);
      JsImageService.getInstance().release(imageKey);
      return cachePath;
    } catch (e) {
      console.warn(`[ComicImageResolver] load failed ${url}: ${e}`);
      if (depth < ComicImageResolver.maxFailDepth && cfg.onLoadFailed) {
        return await ComicImageResolver.resolveConfig(cfg.onLoadFailed, depth + 1);
      }
      return '';
    }
  }

  private static async fetchBody(cfg: ImageLoadingConfigLike): Promise<ArrayBuffer> {
    const headers: Record<string, string> = {};
    if (cfg.headers) {
      const keys = Object.keys(cfg.headers);
      for (let i = 0; i < keys.length; i++) {
        headers[keys[i]] = cfg.headers[keys[i]];
      }
    }
    const res = await HttpService.getInstance().request({
      url: cfg.url ?? '',
      method: cfg.method ?? 'GET',
      headers: headers,
      body: cfg.data,
      bytes: true
    });
    if (res.status < 200 || res.status >= 300 || !(res.body instanceof ArrayBuffer)) {
      throw new Error(`HTTP ${res.status}`);
    }
    return res.body;
  }

  private static async applyOnResponse(onResponse: string | undefined,
    body: ArrayBuffer): Promise<ArrayBuffer> {
    if (!onResponse || onResponse.length === 0 || !JsNativeRuntime.isAvailable()) {
      return body;
    }
    const b64 = ComicImageResolver.bufferToBase64(body);
    const escapedFn = JSON.stringify(onResponse);
    const escapedB64 = JSON.stringify(b64);
    const script =
      `(async function(){` +
      `var data=Convert.decodeBase64(${escapedB64});` +
      `var fn;try{fn=eval(${escapedFn});}catch(e1){try{fn=eval('('+${escapedFn}+')');}catch(e2){throw e2;}}` +
      `if(typeof fn!=='function'){throw new Error('onResponse not a function');}` +
      `var out=fn(data);` +
      `if(!(out instanceof ArrayBuffer)){throw new Error('onResponse must return ArrayBuffer');}` +
      `return Convert.encodeBase64(out);` +
      `})()`;
    const json = await JsNativeRuntime.evaluate(script);
    if (json.length === 0 || json === 'undefined') {
      return body;
    }
    const outB64 = JSON.parse(json) as string;
    return ComicImageResolver.base64ToBuffer(outB64);
  }

  private static async runModifyImage(scriptSrc: string, inputKey: number): Promise<number | null> {
    if (!JsNativeRuntime.isAvailable()) {
      return null;
    }
    const escaped = JSON.stringify(scriptSrc);
    const evalScript =
      `(function(){` +
      `var fn;try{eval(${escaped});}catch(e1){try{eval('('+${escaped}+')');}catch(e2){}}` +
      `if(typeof modifyImage!=='function'){throw new Error('modifyImage not defined');}` +
      `var input=new Image(${inputKey});` +
      `var out=modifyImage(input);` +
      `return(out&&out.key!=null)?out.key:null;` +
      `})()`;
    try {
      const json = await JsNativeRuntime.evaluate(evalScript);
      if (json.length === 0 || json === 'null' || json === 'undefined') {
        return null;
      }
      const key = JSON.parse(json) as number;
      return typeof key === 'number' ? key : null;
    } catch (e) {
      console.error(`[ComicImageResolver] modifyImage failed: ${e}`);
      return null;
    }
  }

  private static bufferToBase64(buf: ArrayBuffer): string {
    return new util.Base64Helper().encodeToStringSync(new Uint8Array(buf));
  }

  private static base64ToBuffer(b64: string): ArrayBuffer {
    return new util.Base64Helper().decodeSync(b64).buffer;
  }
}
