import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Comic, ComicSourceInfo } from '../models/ComicModels';
import { AppConstants } from '../constants/AppConstants';
import { HttpService } from './HttpService';
import { JsEngineBridge } from './JsEngineBridge';
import { ComicSourceDataService } from './ComicSourceDataService';

/**
 * Comic source manager — port of upstream ComicSourceManager.
 * Loads index.json and per-source source.js via JS bridge.
 */
export class ComicSourceService {
  private static instance: ComicSourceService;
  private sources: ComicSourceInfo[] = [];
  private sourcesPath: string = '';

  static getInstance(): ComicSourceService {
    if (!ComicSourceService.instance) {
      ComicSourceService.instance = new ComicSourceService();
    }
    return ComicSourceService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.sourcesPath = `${context.filesDir}/${AppConstants.COMIC_SOURCES_DIR}`;
    try {
      fileIo.mkdirSync(this.sourcesPath);
    } catch (_e) {
      // exists
    }
    await JsEngineBridge.getInstance().init(context);
    ComicSourceDataService.getInstance().init(context);
    await this.refreshIndex();
  }

  getSources(): ComicSourceInfo[] {
    return this.sources;
  }

  async refreshIndex(): Promise<void> {
    try {
      const json = await HttpService.getInstance().get(AppConstants.CONFIG_INDEX_URL);
      const data = JSON.parse(json) as Record<string, Object>;
      this.sources = [];
      if (data['sources'] && Array.isArray(data['sources'])) {
        const arr = data['sources'] as Array<Record<string, string>>;
        for (const item of arr) {
          const info = new ComicSourceInfo();
          info.key = item['key'] ?? '';
          info.name = item['name'] ?? info.key;
          info.version = item['version'] ?? '';
          info.description = item['description'] ?? '';
          info.enabled = true;
          this.sources.push(info);
        }
      }
      await this.prefetchSourceScripts();
    } catch (e) {
      console.error(`[ComicSourceService] index load failed: ${e}`);
      this.sources = [];
    }
  }

  /** 预拉取 source.js 到沙箱，供后续 NAPI QuickJS 加载 */
  private async prefetchSourceScripts(): Promise<void> {
    const base = 'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/sources';
    for (const src of this.sources) {
      if (src.key.length === 0) {
        continue;
      }
      const dest = `${this.sourcesPath}/${src.key}.js`;
      try {
        fileIo.statSync(dest);
        continue;
      } catch (_e) {
        // not cached
      }
      try {
        const script = await HttpService.getInstance().get(`${base}/${src.key}/source.js`);
        const file = fileIo.openSync(dest,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        const bytes = new Uint8Array(script.length);
        for (let i = 0; i < script.length; i++) {
          bytes[i] = script.charCodeAt(i) & 0xff;
        }
        fileIo.writeSync(file.fd, bytes.buffer);
        fileIo.closeSync(file.fd);
        console.info(`[ComicSourceService] cached ${src.key}.js`);
        await JsEngineBridge.getInstance().loadSourceScript(src.key, script);
      } catch (e) {
        console.warn(`[ComicSourceService] prefetch ${src.key} failed: ${e}`);
      }
    }
    JsEngineBridge.getInstance().loadCachedSourcesFromDisk();
  }

  getCachedScriptCount(): number {
    return JsEngineBridge.getInstance().getStagedSourceKeys().length;
  }

  isSourceCached(key: string): boolean {
    return JsEngineBridge.getInstance().isSourceStaged(key);
  }

  async search(keyword: string, sourceKey?: string): Promise<Comic[]> {
    if (sourceKey) {
      return JsEngineBridge.getInstance().invokeSearch(sourceKey, keyword);
    }
    const results: Comic[] = [];
    for (const src of this.sources.filter((s: ComicSourceInfo) => s.enabled)) {
      const partial = await JsEngineBridge.getInstance().invokeSearch(src.key, keyword);
      results.push(...partial);
    }
    return results;
  }

  async getCategories(sourceKey: string): Promise<string[]> {
    return JsEngineBridge.getInstance().invokeCategories(sourceKey);
  }
}
