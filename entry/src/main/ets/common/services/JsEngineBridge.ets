import { fileIo } from '@kit.CoreFileKit';

import { common } from '@kit.AbilityKit';

import { Comic, ComicChapter } from '../models/ComicModels';

import { JsMessageHost, JsMessagePayload } from './JsMessageHost';

import { JsNativeRuntime } from './JsNativeRuntime';



export interface JsEngineStatus {

  initLoaded: boolean;

  initScriptLength: number;

  stagedSourceCount: number;

  runtimeReady: boolean;

  runtimeNote: string;

}



/**

 * QuickJS 漫画源运行时桥接（API 23 NAPI + JsMessageHost）。

 */

export class JsEngineBridge {

  private static instance: JsEngineBridge;

  private initReady: boolean = false;

  private runtimeReady: boolean = false;

  private initScript: string = '';

  private stagedSources: Map<string, string> = new Map();

  private sourcesPath: string = '';



  static getInstance(): JsEngineBridge {

    if (!JsEngineBridge.instance) {

      JsEngineBridge.instance = new JsEngineBridge();

    }

    return JsEngineBridge.instance;

  }



  async init(context: common.UIAbilityContext): Promise<void> {

    this.sourcesPath = `${context.filesDir}/comic_sources`;

    try {

      const buf = await context.resourceManager.getRawFileContent('init.js');

      this.initScript = JsEngineBridge.bytesToString(new Uint8Array(buf));

      this.initReady = this.initScript.length > 0;

      console.info(`[JsEngineBridge] init.js loaded (${this.initScript.length} chars)`);

    } catch (e) {

      console.error(`[JsEngineBridge] failed to load init.js: ${e}`);

      this.initScript = '';

      this.initReady = false;

    }

    if (this.initReady && JsNativeRuntime.isAvailable()) {

      this.runtimeReady = JsNativeRuntime.initRuntime(this.initScript);

      console.info(`[JsEngineBridge] QuickJS runtime ready=${this.runtimeReady}`);

    }

    this.loadCachedSourcesFromDisk();

    if (this.runtimeReady) {

      this.registerAllStagedToNative();

    }

  }



  private static bytesToString(bytes: Uint8Array): string {

    let script = '';

    for (let i = 0; i < bytes.length; i++) {

      script += String.fromCharCode(bytes[i]);

    }

    return script;

  }



  isReady(): boolean {

    return this.initReady;

  }



  getStatus(): JsEngineStatus {

    return {

      initLoaded: this.initReady,

      initScriptLength: this.initScript.length,

      stagedSourceCount: this.stagedSources.size,

      runtimeReady: this.runtimeReady,

      runtimeNote: this.runtimeReady ?

        'QuickJS NAPI 已就绪（HTTP: RCP FetchSync）' :

        'init.js 已载入；设备未加载 libvenera_qjs.so'

    };

  }



  getStagedSourceKeys(): string[] {

    return Array.from(this.stagedSources.keys());

  }



  isSourceStaged(sourceKey: string): boolean {

    return this.stagedSources.has(sourceKey);

  }



  async dispatchMessage(payload: JsMessagePayload): Promise<Object | null> {

    return JsMessageHost.getInstance().handle(payload);

  }



  buildSearchScript(sourceKey: string, keyword: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeWord = JsEngineBridge.escapeJs(keyword);
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.search||!src.search.load)return[];var res=await src.search.load(${safeWord},null,1);return(res&&res.comics)?res.comics:[];})()`;
  }

  buildCategoriesScript(sourceKey: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    return `(function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.category||!src.category.parts)return[];var out=[];for(var pi=0;pi<src.category.parts.length;pi++){var part=src.category.parts[pi];if(part.categories&&Array.isArray(part.categories)){for(var ci=0;ci<part.categories.length;ci++){var c=part.categories[ci];if(typeof c==='string')out.push(c);else if(c&&c.label)out.push(c.label);}}else if(part.name){out.push(part.name);}}return out;})()`;
  }

  buildComicChaptersScript(sourceKey: string, comicId: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.comic||!src.comic.loadInfo)return null;var info=await src.comic.loadInfo(${safeComic});return(info&&info.chapters)?info.chapters:null;})()`;
  }

  buildComicPagesScript(sourceKey: string, comicId: string, chapterId: string): string {
    const safeKey = JsEngineBridge.escapeJs(sourceKey);
    const safeComic = JsEngineBridge.escapeJs(comicId);
    const safeChapter = JsEngineBridge.escapeJs(chapterId);
    return `(async function(){var src=ComicSource.sources[${safeKey}];if(!src||!src.comic||!src.comic.loadEp)return[];var res=await src.comic.loadEp(${safeComic},${safeChapter});return(res&&res.images)?res.images:[];})()`;
  }



  private static escapeJs(value: string): string {

    return JSON.stringify(value);

  }



  private parseComics(raw: Object | null): Comic[] {

    if (!raw || !Array.isArray(raw)) {

      return [];

    }

    const arr = raw as Array<Record<string, Object>>;

    const comics: Comic[] = [];

    for (let i = 0; i < arr.length; i++) {

      const item = arr[i];

      const c = new Comic();

      c.id = `${item['id'] ?? ''}`;

      c.title = `${item['title'] ?? ''}`;

      c.cover = `${item['cover'] ?? ''}`;

      c.description = `${item['description'] ?? ''}`;

      c.sourceKey = `${item['sourceKey'] ?? item['source'] ?? ''}`;

      if (c.sourceKey.length === 0 && item['key']) {

        c.sourceKey = `${item['key']}`;

      }

      comics.push(c);

    }

    return comics;

  }



  private parseChapters(raw: Object | null): ComicChapter[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Array<Record<string, Object>>;
    const chapters: ComicChapter[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      const ch = new ComicChapter();
      ch.id = `${item['id'] ?? ''}`;
      ch.title = `${item['title'] ?? item['name'] ?? ''}`;
      ch.subTitle = item['subTitle'] ? `${item['subTitle']}` : undefined;
      ch.cover = item['cover'] ? `${item['cover']}` : undefined;
      chapters.push(ch);
    }
    return chapters;
  }

  /** 解析 comic.loadInfo 返回的 chapters 对象（平铺或分组 Map） */
  private parseChaptersFromLoadInfo(raw: Object | null): ComicChapter[] {
    if (!raw || typeof raw !== 'object') {
      return [];
    }
    const chaptersObj = raw as Record<string, Object>;
    const out: ComicChapter[] = [];
    const keys = Object.keys(chaptersObj);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = chaptersObj[key];
      if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        const group = value as Record<string, Object>;
        const groupKeys = Object.keys(group);
        for (let j = 0; j < groupKeys.length; j++) {
          const epId = groupKeys[j];
          const ch = new ComicChapter();
          ch.id = epId;
          ch.title = `${group[epId]}`;
          ch.subTitle = key;
          out.push(ch);
        }
      } else {
        const ch = new ComicChapter();
        ch.id = key;
        ch.title = `${value}`;
        out.push(ch);
      }
    }
    return out;
  }



  private parseStringList(raw: Object | null): string[] {

    if (!raw || !Array.isArray(raw)) {

      return [];

    }

    const arr = raw as Array<Object>;

    const out: string[] = [];

    for (let i = 0; i < arr.length; i++) {

      out.push(`${arr[i]}`);

    }

    return out;

  }



  private evaluateJson(script: string, tag: string): Object | null {

    if (!this.runtimeReady) {

      return null;

    }

    try {

      const json = JsNativeRuntime.evaluate(script);

      if (json.length === 0 || json === 'undefined') {

        return null;

      }

      return JSON.parse(json) as Object;

    } catch (e) {

      console.error(`[JsEngineBridge] ${tag} eval error: ${e}`);

      return null;

    }

  }



  async invokeSearch(sourceKey: string, keyword: string): Promise<Comic[]> {

    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {

      return [];

    }

    const script = this.buildSearchScript(sourceKey, keyword);

    const raw = this.evaluateJson(script, 'invokeSearch');

    const comics = this.parseComics(raw);

    for (let i = 0; i < comics.length; i++) {

      if (comics[i].sourceKey.length === 0) {

        comics[i].sourceKey = sourceKey;

      }

    }

    return comics;

  }



  async invokeCategories(sourceKey: string): Promise<string[]> {

    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {

      return [];

    }

    const script = this.buildCategoriesScript(sourceKey);

    return this.parseStringList(this.evaluateJson(script, 'invokeCategories'));

  }



  async invokeComicPages(sourceKey: string, comicId: string, chapterId: string): Promise<string[]> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return [];
    }
    const script = this.buildComicPagesScript(sourceKey, comicId, chapterId);
    return this.parseStringList(this.evaluateJson(script, 'invokeComicPages'));
  }

  async invokeComicChapters(sourceKey: string, comicId: string): Promise<ComicChapter[]> {
    if (!this.runtimeReady || !this.stagedSources.has(sourceKey)) {
      return [];
    }
    const script = this.buildComicChaptersScript(sourceKey, comicId);
    const raw = this.evaluateJson(script, 'invokeComicChapters');
    if (Array.isArray(raw)) {
      return this.parseChapters(raw);
    }
    return this.parseChaptersFromLoadInfo(raw);
  }



  async loadSourceScript(sourceKey: string, scriptContent: string): Promise<boolean> {

    if (scriptContent.length === 0 || sourceKey.length === 0) {

      return false;

    }

    this.stagedSources.set(sourceKey, scriptContent);

    if (this.runtimeReady) {

      return JsNativeRuntime.loadSource(sourceKey, scriptContent);

    }

    return this.initReady;

  }



  private registerAllStagedToNative(): void {

    const keys = Array.from(this.stagedSources.keys());

    for (let i = 0; i < keys.length; i++) {

      const key = keys[i];

      const script = this.stagedSources.get(key) ?? '';

      if (script.length > 0) {

        JsNativeRuntime.loadSource(key, script);

      }

    }

  }



  readCachedSourceScript(sourceKey: string, sourcesPath?: string): string {

    const root = sourcesPath ?? this.sourcesPath;

    try {

      const path = `${root}/${sourceKey}.js`;

      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);

      const stat = fileIo.statSync(path);

      const buf = new ArrayBuffer(stat.size);

      fileIo.readSync(file.fd, buf);

      fileIo.closeSync(file.fd);

      return JsEngineBridge.bytesToString(new Uint8Array(buf));

    } catch (_e) {

      return '';

    }

  }



  loadCachedSourcesFromDisk(): void {

    if (this.sourcesPath.length === 0) {

      return;

    }

    try {

      const names = fileIo.listFileSync(this.sourcesPath);

      for (const name of names) {

        if (!name.endsWith('.js')) {

          continue;

        }

        const key = name.substring(0, name.length - 3);

        const script = this.readCachedSourceScript(key, this.sourcesPath);

        if (script.length > 0) {

          this.stagedSources.set(key, script);

        }

      }

      console.info(`[JsEngineBridge] staged ${this.stagedSources.size} cached sources`);

    } catch (_e) {

      // empty dir

    }

  }

}

