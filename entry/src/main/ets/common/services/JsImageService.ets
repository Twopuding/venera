import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

/** init.js Image API 对应的 RGBA 位图槽（同步 sendMessage 路径） */
interface ImageSlot {
  width: number;
  height: number;
  rgba: Uint8Array;
}

/**
 * init.js Image.* 宿主实现（API 23 ImageKit 解码/编码 + 同步 RGBA 运算）。
 * 供 comic.onImageLoad.modifyImage 拼图解码使用。
 */
export class JsImageService {
  private static instance: JsImageService;
  private slots: Map<number, ImageSlot> = new Map();
  private nextKey: number = 1;

  static getInstance(): JsImageService {
    if (!JsImageService.instance) {
      JsImageService.instance = new JsImageService();
    }
    return JsImageService.instance;
  }

  /** QuickJS sendMessage image 同步分发 */
  handle(payload: Record<string, Object>): number | null {
    const fn = `${payload['function'] ?? ''}`;
    switch (fn) {
      case 'copyRange': {
        const key = JsImageService.num(payload['key']);
        const x = JsImageService.num(payload['x']);
        const y = JsImageService.num(payload['y']);
        const w = JsImageService.num(payload['width']);
        const h = JsImageService.num(payload['height']);
        return this.copyRange(key, x, y, w, h);
      }
      case 'copyAndRotate90':
        return this.copyAndRotate90(JsImageService.num(payload['key']));
      case 'fillImageAt':
        this.fillImageAt(
          JsImageService.num(payload['key']),
          JsImageService.num(payload['x']),
          JsImageService.num(payload['y']),
          JsImageService.num(payload['image'])
        );
        return null;
      case 'fillImageRangeAt':
        this.fillImageRangeAt(
          JsImageService.num(payload['key']),
          JsImageService.num(payload['x']),
          JsImageService.num(payload['y']),
          JsImageService.num(payload['image']),
          JsImageService.num(payload['srcX']),
          JsImageService.num(payload['srcY']),
          JsImageService.num(payload['width']),
          JsImageService.num(payload['height'])
        );
        return null;
      case 'getWidth':
        return this.getWidth(JsImageService.num(payload['key']));
      case 'getHeight':
        return this.getHeight(JsImageService.num(payload['key']));
      case 'emptyImage':
        return this.emptyImage(
          JsImageService.num(payload['width']),
          JsImageService.num(payload['height'])
        );
      default:
        console.warn(`[JsImageService] unknown function: ${fn}`);
        return null;
    }
  }

  /** 从 JPEG/PNG/WebP 等字节解码并注册，返回 Image.key */
  async registerFromBytes(bytes: ArrayBuffer): Promise<number> {
    const src = image.createImageSource(bytes);
    const pixelMap = await src.createPixelMap({ editable: true });
    const info = await pixelMap.getImageInfo();
    const w = info.size.width;
    const h = info.size.height;
    const buf = new ArrayBuffer(w * h * 4);
    const area: image.PositionArea = {
      pixels: buf,
      offset: 0,
      stride: w * 4,
      region: { x: 0, y: 0, size: { width: w, height: h } }
    };
    await pixelMap.readPixels(area);
    pixelMap.release();
    return this.registerRgba(w, h, new Uint8Array(buf));
  }

  registerRgba(width: number, height: number, rgba: Uint8Array): number {
    const key = this.nextKey++;
    this.slots.set(key, { width: width, height: height, rgba: rgba });
    return key;
  }

  async exportToFile(key: number, destPath: string): Promise<void> {
    const slot = this.slots.get(key);
    if (!slot) {
      throw new Error(`image key ${key} not found`);
    }
    const slash = destPath.lastIndexOf('/');
    if (slash > 0) {
      try {
        fileIo.mkdirSync(destPath.substring(0, slash), true);
      } catch (_e) {
        // exists
      }
    }
    const initOpts: image.InitializationOptions = {
      size: { width: slot.width, height: slot.height },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    };
    const pixelMap = image.createPixelMapSync(slot.rgba.buffer, initOpts);
    const file = fileIo.openSync(destPath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const packer = image.createImagePacker();
    await packer.packToFile(pixelMap, file.fd, { format: 'image/jpeg', quality: 92 });
    fileIo.closeSync(file.fd);
    pixelMap.release();
  }

  release(key: number): void {
    this.slots.delete(key);
  }

  private slot(key: number): ImageSlot | undefined {
    return this.slots.get(key);
  }

  private emptyImage(width: number, height: number): number {
    const w = Math.max(1, Math.floor(width));
    const h = Math.max(1, Math.floor(height));
    const rgba = new Uint8Array(w * h * 4);
    return this.registerRgba(w, h, rgba);
  }

  private getWidth(key: number): number {
    return this.slot(key)?.width ?? 0;
  }

  private getHeight(key: number): number {
    return this.slot(key)?.height ?? 0;
  }

  private copyRange(key: number, x: number, y: number, w: number, h: number): number | null {
    const src = this.slot(key);
    if (!src || w <= 0 || h <= 0) {
      return null;
    }
    const out = new Uint8Array(w * h * 4);
    for (let row = 0; row < h; row++) {
      const sy = y + row;
      if (sy < 0 || sy >= src.height) {
        continue;
      }
      for (let col = 0; col < w; col++) {
        const sx = x + col;
        if (sx < 0 || sx >= src.width) {
          continue;
        }
        const si = (sy * src.width + sx) * 4;
        const di = (row * w + col) * 4;
        out[di] = src.rgba[si];
        out[di + 1] = src.rgba[si + 1];
        out[di + 2] = src.rgba[si + 2];
        out[di + 3] = src.rgba[si + 3];
      }
    }
    return this.registerRgba(w, h, out);
  }

  private copyAndRotate90(key: number): number | null {
    const src = this.slot(key);
    if (!src) {
      return null;
    }
    const w = src.height;
    const h = src.width;
    const out = new Uint8Array(w * h * 4);
    for (let y = 0; y < src.height; y++) {
      for (let x = 0; x < src.width; x++) {
        const si = (y * src.width + x) * 4;
        const nx = src.height - 1 - y;
        const ny = x;
        const di = (ny * w + nx) * 4;
        out[di] = src.rgba[si];
        out[di + 1] = src.rgba[si + 1];
        out[di + 2] = src.rgba[si + 2];
        out[di + 3] = src.rgba[si + 3];
      }
    }
    return this.registerRgba(w, h, out);
  }

  private fillImageAt(dstKey: number, x: number, y: number, srcKey: number): void {
    this.fillImageRangeAt(dstKey, x, y, srcKey, 0, 0,
      this.getWidth(srcKey), this.getHeight(srcKey));
  }

  private fillImageRangeAt(dstKey: number, dx: number, dy: number, srcKey: number,
    srcX: number, srcY: number, w: number, h: number): void {
    const dst = this.slot(dstKey);
    const src = this.slot(srcKey);
    if (!dst || !src) {
      return;
    }
    for (let row = 0; row < h; row++) {
      const sy = srcY + row;
      const ty = dy + row;
      if (sy < 0 || sy >= src.height || ty < 0 || ty >= dst.height) {
        continue;
      }
      for (let col = 0; col < w; col++) {
        const sx = srcX + col;
        const tx = dx + col;
        if (sx < 0 || sx >= src.width || tx < 0 || tx >= dst.width) {
          continue;
        }
        const si = (sy * src.width + sx) * 4;
        const di = (ty * dst.width + tx) * 4;
        dst.rgba[di] = src.rgba[si];
        dst.rgba[di + 1] = src.rgba[si + 1];
        dst.rgba[di + 2] = src.rgba[si + 2];
        dst.rgba[di + 3] = src.rgba[si + 3];
      }
    }
  }

  private static num(v: Object | undefined): number {
    if (typeof v === 'number') {
      return v;
    }
    if (typeof v === 'string') {
      const n = Number(v);
      return isNaN(n) ? 0 : n;
    }
    return 0;
  }
}
