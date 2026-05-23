import qjs from 'libvenera_qjs.so';
import { JsMessageHost, JsMessagePayload } from './JsMessageHost';
import { AppConstants } from '../constants/AppConstants';

/**
 * QuickJS NAPI（libvenera_qjs.so，API 23）。
 * init.js 须在主线程执行，且先于 runInitScript 完成 registerMessageHandler。
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
    const version = AppConstants.HARMONY_VERSION;
    if (!(qjs.prepareRuntime(version) as boolean)) {
      console.error('[JsNativeRuntime] prepareRuntime failed');
      return false;
    }
    const registered = qjs.registerMessageHandler(JsNativeRuntime.handleMessageJson) as boolean;
    if (!registered) {
      console.error('[JsNativeRuntime] registerMessageHandler failed');
      return false;
    }
    const ok = qjs.runInitScript(initJs) as boolean;
    JsNativeRuntime.handlerReady = ok;
    if (!ok) {
      console.error('[JsNativeRuntime] runInitScript failed');
    }
    return ok;
  }

  static async loadSource(sourceKey: string, script: string): Promise<boolean> {
    if (!JsNativeRuntime.handlerReady) {
      return false;
    }
    return await qjs.loadSource(sourceKey, script) as boolean;
  }

  static async evaluate(script: string): Promise<string> {
    if (!JsNativeRuntime.handlerReady) {
      return 'null';
    }
    return await qjs.evaluate(script) as string;
  }

  static resetSources(): void {
    if (JsNativeRuntime.handlerReady) {
      qjs.resetSources();
    }
  }

  static extract7z(archivePath: string, outDir: string): boolean {
    if (!JsNativeRuntime.isAvailable()) {
      return false;
    }
    try {
      return qjs.extract7z(archivePath, outDir) as boolean;
    } catch (_e) {
      return false;
    }
  }
}
