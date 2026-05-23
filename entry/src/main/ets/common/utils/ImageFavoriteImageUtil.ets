import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ImageFavorite } from '../models/ImageFavoriteModels';
import { ComicImageResolver } from './ComicImageResolver';
import { JsEngineBridge } from '../services/JsEngineBridge';

/**
 * 图片收藏缩略图/大图路径 — 对齐 upstream ImageFavoritesProvider
 */
export class ImageFavoriteImageUtil {
  private static cacheDir: string = '';

  static init(context: common.UIAbilityContext): void {
    ImageFavoriteImageUtil.cacheDir = `${context.cacheDir}/image_favorites`;
    try {
      fileIo.mkdirSync(ImageFavoriteImageUtil.cacheDir, true);
    } catch (_e) {
      // exists
    }
  }

  static selectionKey(img: ImageFavorite): string {
    return `${img.sourceKey}|${img.id}|${img.eid}|${img.ep}|${img.page}`;
  }

  private static cacheFileName(img: ImageFavorite): string {
    const key = ImageFavoriteImageUtil.selectionKey(img);
    let h = 0;
    for (let i = 0; i < key.length; i++) {
      h = ((h << 5) - h + key.charCodeAt(i)) | 0;
    }
    return `${Math.abs(h).toString(16)}.img`;
  }

  private static readCachePath(img: ImageFavorite): string {
    const path = `${ImageFavoriteImageUtil.cacheDir}/${ImageFavoriteImageUtil.cacheFileName(img)}`;
    try {
      fileIo.accessSync(path);
      return path;
    } catch (_e) {
      return '';
    }
  }

  private static async writeCacheFromFile(img: ImageFavorite, srcPath: string): Promise<string> {
    const dest = `${ImageFavoriteImageUtil.cacheDir}/${ImageFavoriteImageUtil.cacheFileName(img)}`;
    try {
      fileIo.copyFileSync(srcPath, dest);
      return dest;
    } catch (_e) {
      return srcPath;
    }
  }

  private static async fetchImageKey(img: ImageFavorite): Promise<string> {
    const entries = await JsEngineBridge.getInstance()
      .invokeComicPageEntries(img.sourceKey, img.id, img.eid);
    const idx = img.page - 1;
    if (idx < 0 || idx >= entries.length) {
      return '';
    }
    const entry = entries[idx];
    if (typeof entry === 'string') {
      return entry;
    }
    if (entry !== null && typeof entry === 'object') {
      const u = (entry as Record<string, Object>)['url'];
      if (typeof u === 'string') {
        return u;
      }
    }
    return '';
  }

  /** 解析为可读本地路径（file:// 或沙箱路径） */
  static async resolvePath(img: ImageFavorite): Promise<string> {
    const cached = ImageFavoriteImageUtil.readCachePath(img);
    if (cached.length > 0) {
      return cached;
    }
    let imageKey = img.imageKey;
    if (imageKey.length === 0) {
      imageKey = await ImageFavoriteImageUtil.fetchImageKey(img);
    }
    if (imageKey.length === 0) {
      return '';
    }
    const path = await ComicImageResolver.resolvePage(imageKey);
    if (path.length === 0) {
      return '';
    }
    return ImageFavoriteImageUtil.writeCacheFromFile(img, path);
  }

  static async resolvePaths(images: ImageFavorite[]): Promise<string[]> {
    const out: string[] = [];
    for (let i = 0; i < images.length; i++) {
      out.push(await ImageFavoriteImageUtil.resolvePath(images[i]));
    }
    return out;
  }
}
