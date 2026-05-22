import qjs from 'libvenera_qjs.so';
import { JsMessageHost, JsMessagePayload } from './JsMessageHost';
import { AppConstants } from '../constants/AppConstants';

/**
 * QuickJS NAPI（libvenera_qjs.so，API 23）。
 * HTTP 由原生 HMS_Rcp_FetchSync 处理；其余 sendMessage 走 ArkTS 同步宿主。
 */
export class JsNativeRuntime {
  private static handlerReady: boolean = false;

  static handleMessageJson(json: string): string {
    try {
      const payload = JSON.parse(json) as JsMessagePayload;
      const result = JsMessageHost.getInstance().handleSync(payload);
      if (result === null || result === undefined) {
        return 'null';
      }
      if (result instanceof ArrayBuffer) {
        return JSON.stringify(Array.from(new Uint8Array(result)));
      }
      return JSON.stringify(result);
    } catch (e) {
      console.error(`[JsNativeRuntime] handleMessageJson: ${e}`);
      return 'null';
    }
  }

  static isAvailable(): boolean {
    try {
      return qjs.isAvailable() as boolean;
    } catch (_e) {
      return false;
    }
  }

  static initRuntime(initJs: string): boolean {
    if (!JsNativeRuntime.isAvailable()) {
      return false;
    }
    const ok = qjs.initRuntime(initJs, AppConstants.HARMONY_VERSION) as boolean;
    if (!ok) {
      return false;
    }
    const registered = qjs.registerMessageHandler(JsNativeRuntime.handleMessageJson) as boolean;
    JsNativeRuntime.handlerReady = registered;
    return registered;
  }

  static loadSource(sourceKey: string, script: string): boolean {
    if (!JsNativeRuntime.handlerReady) {
      return false;
    }
    return qjs.loadSource(sourceKey, script) as boolean;
  }

  static evaluate(script: string): string {
    if (!JsNativeRuntime.handlerReady) {
      return 'null';
    }
    return qjs.evaluate(script) as string;
  }

  static resetSources(): void {
    if (JsNativeRuntime.handlerReady) {
      qjs.resetSources();
    }
  }
}
