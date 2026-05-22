import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';

/**
 * 阅读器图片磁盘缓存（API 23 沙箱 cacheDir）。
 * 本地 file:// 路径原样返回；http(s) 下载后复用。
 */
export class ImageCacheUtil {
  private static cacheDir: string = '';
  private static memoryHits: Map<string, string> = new Map();

  static init(context: common.UIAbilityContext): void {
    ImageCacheUtil.cacheDir = `${context.cacheDir}/reader_images`;
    try {
      fileIo.mkdirSync(ImageCacheUtil.cacheDir, true);
    } catch (_e) {
      // exists
    }
  }

  static isRemoteUrl(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static hashKey(url: string): string {
    let h = 0;
    for (let i = 0; i < url.length; i++) {
      h = ((h << 5) - h + url.charCodeAt(i)) | 0;
    }
    const ext = ImageCacheUtil.guessExtension(url);
    return `${Math.abs(h).toString(16)}${ext}`;
  }

  private static guessExtension(url: string): string {
    const q = url.indexOf('?');
    const path = q >= 0 ? url.substring(0, q) : url;
    const dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 2) {
      return '.img';
    }
    const ext = path.substring(dot).toLowerCase();
    if (ext.length > 6) {
      return '.img';
    }
    return ext;
  }

  /** 同步解析：已缓存则返回本地路径，否则返回原 URL（由 ensureCached 异步落盘） */
  static resolveSync(urlOrPath: string): string {
    if (!ImageCacheUtil.isRemoteUrl(urlOrPath)) {
      return urlOrPath;
    }
    const hit = ImageCacheUtil.memoryHits.get(urlOrPath);
    if (hit) {
      return hit;
    }
    const local = `${ImageCacheUtil.cacheDir}/${ImageCacheUtil.hashKey(urlOrPath)}`;
    try {
      fileIo.statSync(local);
      ImageCacheUtil.memoryHits.set(urlOrPath, local);
      return local;
    } catch (_e) {
      return urlOrPath;
    }
  }

  static async ensureCached(url: string): Promise<string> {
    if (!ImageCacheUtil.isRemoteUrl(url)) {
      return url;
    }
    const cached = ImageCacheUtil.resolveSync(url);
    if (cached !== url) {
      return cached;
    }
    const dest = `${ImageCacheUtil.cacheDir}/${ImageCacheUtil.hashKey(url)}`;
    try {
      await HttpService.getInstance().downloadFile(url, dest);
      ImageCacheUtil.memoryHits.set(url, dest);
      return dest;
    } catch (e) {
      console.warn(`[ImageCacheUtil] cache miss ${url}: ${e}`);
      return url;
    }
  }

  static async resolveAll(urls: string[]): Promise<string[]> {
    const out: string[] = [];
    for (let i = 0; i < urls.length; i++) {
      out.push(await ImageCacheUtil.ensureCached(urls[i]));
    }
    return out;
  }
}
