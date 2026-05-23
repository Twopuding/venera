import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/** convert 消息字段（与 JsMessagePayload 对齐，供宿主传入） */
export interface JsConvertRequest {
  type?: string;
  isEncode?: boolean;
  isString?: boolean;
  value?: string | ArrayBuffer;
  hash?: string;
  key?: string | ArrayBuffer;
}

/**
 * init.js Convert.* 宿主实现（API 23 CryptoArchitectureKit + Base64Helper）。
 */
export class JsConvertUtil {
  private static base64 = new util.Base64Helper();
  private static textEncoder = new util.TextEncoder();
  private static textDecoder = new util.TextDecoder('utf-8');
  private static gbkDecoder: util.TextDecoder | undefined = undefined;

  static toBytes(value: string | ArrayBuffer | undefined): Uint8Array {
    if (value === undefined) {
      return new Uint8Array(0);
    }
    if (typeof value === 'string') {
      return JsConvertUtil.textEncoder.encode(value);
    }
    return new Uint8Array(value);
  }

  static async digest(alg: string, data: Uint8Array): Promise<Uint8Array> {
    const md = cryptoFramework.createMd(alg);
    await md.update({ data: data });
    const out = await md.digest();
    return out.data;
  }

  static async hmac(hash: string, key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const macAlg = `HMAC${hash.toUpperCase()}`;
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
    const symKey = await symKeyGenerator.convertKey({ data: key });
    const mac = cryptoFramework.createMac(macAlg);
    await mac.init(symKey);
    await mac.update({ data: data });
    const out = await mac.doFinal();
    return out.data;
  }

  static bytesToHex(bytes: Uint8Array): string {
    let hex = '';
    for (let i = 0; i < bytes.length; i++) {
      const n = bytes[i].toString(16).padStart(2, '0');
      hex += n;
    }
    return hex;
  }

  /** 同步 convert（utf8/base64）；哈希类在 QuickJS 线程中仍走异步 handle */
  static handleSync(message: JsConvertRequest): string | ArrayBuffer | null {
    const type = message.type ?? '';
    const isEncode = message.isEncode === true;
    const raw = message.value;
    const value = (typeof raw === 'string' || raw instanceof ArrayBuffer) ? raw as string | ArrayBuffer : undefined;
    if (type === 'utf8') {
      if (isEncode) {
        const str = typeof value === 'string' ? value : '';
        return JsConvertUtil.textEncoder.encode(str).buffer;
      }
      if (value instanceof ArrayBuffer) {
        return JsConvertUtil.textDecoder.decodeToString(new Uint8Array(value));
      }
      return '';
    }
    if (type === 'base64') {
      if (isEncode && value instanceof ArrayBuffer) {
        return JsConvertUtil.base64.encodeToStringSync(new Uint8Array(value));
      }
      if (!isEncode && typeof value === 'string') {
        return JsConvertUtil.base64.decodeSync(value).buffer;
      }
      return null;
    }
    if (type === 'gbk') {
      return JsConvertUtil.handleGbkSync(isEncode, value);
    }
    return null;
  }

  static async handle(message: JsConvertRequest): Promise<string | ArrayBuffer | null> {
    const type = message.type ?? '';
    const isEncode = message.isEncode === true;
    const isString = message.isString === true;
    const rawValue = message.value;
    const value = (typeof rawValue === 'string' || rawValue instanceof ArrayBuffer) ?
      rawValue as string | ArrayBuffer : undefined;

    if (type === 'utf8') {
      if (isEncode) {
        const str = typeof value === 'string' ? value : '';
        return JsConvertUtil.textEncoder.encode(str).buffer;
      }
      if (value instanceof ArrayBuffer) {
        return JsConvertUtil.textDecoder.decodeToString(new Uint8Array(value));
      }
      return '';
    }

    if (type === 'base64') {
      if (isEncode && value instanceof ArrayBuffer) {
        return JsConvertUtil.base64.encodeToStringSync(new Uint8Array(value));
      }
      if (!isEncode && typeof value === 'string') {
        return JsConvertUtil.base64.decodeSync(value).buffer;
      }
      return null;
    }

    if (type === 'gbk') {
      return JsConvertUtil.handleGbkSync(isEncode, value);
    }

    const hashTypes = ['md5', 'sha1', 'sha256', 'sha512'];
    if (hashTypes.indexOf(type) >= 0) {
      const bytes = JsConvertUtil.toBytes(value);
      const alg = type === 'md5' ? 'MD5' : type.toUpperCase();
      const digest = await JsConvertUtil.digest(alg, bytes);
      if (isString) {
        return JsConvertUtil.bytesToHex(digest);
      }
      return digest.buffer;
    }

    if (type === 'hmac') {
      const hashName = message.hash ?? 'sha256';
      const rawKey = message.key;
      const keyBytes = (rawKey instanceof ArrayBuffer) ?
        new Uint8Array(rawKey) : JsConvertUtil.toBytes(typeof rawKey === 'string' ? rawKey : '');
      const dataBytes = JsConvertUtil.toBytes(value);
      const out = await JsConvertUtil.hmac(hashName, keyBytes, dataBytes);
      if (isString) {
        return JsConvertUtil.bytesToHex(out);
      }
      return out.buffer;
    }

    console.warn(`[JsConvertUtil] unsupported convert type: ${type}`);
    return null;
  }

  private static handleGbkSync(isEncode: boolean, value: string | ArrayBuffer | undefined): string | ArrayBuffer | null {
    if (isEncode) {
      console.warn('[JsConvertUtil] GBK encode: use QuickJS 同步 convert 原生路径');
      return null;
    }
    try {
      if (!JsConvertUtil.gbkDecoder) {
        JsConvertUtil.gbkDecoder = new util.TextDecoder('gbk');
      }
    } catch (e) {
      console.warn(`[JsConvertUtil] GBK decode unavailable: ${e}`);
      return null;
    }
    if (value instanceof ArrayBuffer) {
      return JsConvertUtil.gbkDecoder!.decodeToString(new Uint8Array(value));
    }
    return '';
  }
}
