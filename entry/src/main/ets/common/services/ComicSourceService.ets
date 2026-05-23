import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import {
  CategoryComicsResult,
  CategoryItem,
  Comic,
  ComicSourceInfo,
  ExplorePageLoadResult,
  ExploreSection,
  InstalledComicSource,
  RankingPageInfo,
  SourceAccountConfig,
  SourceSettingDef
} from '../models/ComicModels';
import { AppConstants } from '../constants/AppConstants';
import { ENGINE_READY_KEY } from '../constants/StartupKeys';
import { HttpService } from './HttpService';
import { JsEngineBridge } from './JsEngineBridge';
import { ComicSourceDataService } from './ComicSourceDataService';
import { AppDataService } from './AppDataService';
import { FileIoUtil } from '../utils/FileIoUtil';
import { SemVerUtil } from '../utils/SemVerUtil';
import { SourceScriptUtil } from '../utils/SourceScriptUtil';

/**
 * Comic source manager — port of upstream ComicSourceManager + venera-configs index.
 * 内置 rawfile/comic_sources（31 个官方图源），离线可装；联网时从 CDN 更新 index/脚本。
 */
export class ComicSourceService {
  private static instance: ComicSourceService;
  private sources: ComicSourceInfo[] = [];
  private sourcesPath: string = '';
  private appContext?: common.UIAbilityContext;
  /** QuickJS + index 后台初始化（不阻塞启动首屏） */
  private engineReadyPromise?: Promise<void>;
  private engineFullyReady: boolean = false;
  private static readonly utf8Decoder = new util.TextDecoder('utf-8');
  /** key -> 远程 index 中的新版本号 */
  private availableUpdates: Map<string, string> = new Map();

  static getInstance(): ComicSourceService {
    if (!ComicSourceService.instance) {
      ComicSourceService.instance = new ComicSourceService();
    }
    return ComicSourceService.instance;
  }

  /** 启动快速路径：目录与数据服务，不初始化 QuickJS / index */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context;
    this.sourcesPath = `${context.filesDir}/${AppConstants.COMIC_SOURCES_DIR}`;
    try {
      fileIo.mkdirSync(this.sourcesPath);
    } catch (_e) {
      // exists
    }
    ComicSourceDataService.getInstance().init(context);
    const settings = AppDataService.getInstance().settings;
    if (settings.comicSourceListUrl.length === 0) {
      settings.comicSourceListUrl = AppConstants.CONFIG_INDEX_URL;
    }
  }

  /** 默认图源与 QuickJS 是否已在后台装入完成 */
  isEngineReady(): boolean {
    return this.engineFullyReady;
  }

  markEngineFullyReady(): void {
    this.engineFullyReady = true;
    AppStorage.setOrCreate(ENGINE_READY_KEY, true);
  }

  /** 后台装入 QuickJS 与图源 index（首次调用时执行，可 await） */
  async ensureEngineReady(): Promise<void> {
    if (!this.appContext) {
      return;
    }
    if (!this.engineReadyPromise) {
      this.engineReadyPromise = this.initEngineAndIndex();
    }
    await this.engineReadyPromise;
  }

  private async initEngineAndIndex(): Promise<void> {
    if (!this.appContext) {
      return;
    }
    await ComicSourceService.yieldToUi();
    await JsEngineBridge.getInstance().init(this.appContext);
    await this.loadBundledIndex();
  }

  /** 联网刷新 index 与图源脚本（启动后后台执行，不阻塞 UI） */
  async syncFromNetwork(): Promise<void> {
    await this.refreshIndex();
  }

  private async loadBundledIndex(): Promise<void> {
    const json = await this.readBundledIndexJson();
    if (json.length === 0) {
      console.error('[ComicSourceService] no bundled index available');
      this.sources = [];
      return;
    }
    this.sources = ComicSourceService.parseIndexJson(json);
    await this.syncExplorePagesFromSources();
    console.info('[ComicSourceService] index loaded from bundled rawfile');
  }

  getSources(): ComicSourceInfo[] {
    return this.sources;
  }

  /** 官方图源总数（index 条目数） */
  getIndexSourceCount(): number {
    return this.sources.length;
  }

  async refreshIndex(): Promise<void> {
    let json = '';
    try {
      json = await HttpService.getInstance().get(AppConstants.CONFIG_INDEX_URL);
      console.info('[ComicSourceService] index loaded from CDN');
    } catch (e) {
      console.warn(`[ComicSourceService] remote index failed: ${e}`);
    }
    if (json.length === 0) {
      json = await this.readBundledIndexJson();
      if (json.length > 0) {
        console.info('[ComicSourceService] index loaded from bundled rawfile');
      }
    }
    if (json.length === 0) {
      console.error('[ComicSourceService] no index available');
      this.sources = [];
      return;
    }
    this.sources = ComicSourceService.parseIndexJson(json);
    await this.syncExplorePagesFromSources();
  }

  /** 默认三源：Picacg、绅士漫画(wnacg)、禁漫天堂(jm) */
  async installDefaultSourceScripts(allowNetwork: boolean = true): Promise<void> {
    await this.installSourceScripts(AppConstants.DEFAULT_SOURCE_KEYS, allowNetwork);
  }

  /** 将全部内置/索引中的图源脚本装入 QuickJS（跳过已加载项） */
  async installAllSourceScripts(allowNetwork: boolean = true): Promise<void> {
    const allKeys: string[] = [];
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].key.length > 0) {
        allKeys.push(this.sources[i].key);
      }
    }
    await this.installSourceScripts(allKeys, allowNetwork);
  }

  /** 按 key 列表装入图源（跳过已加载项） */
  async installSourceScripts(keys: string[], allowNetwork: boolean = true): Promise<void> {
    const nativeKeys: string[] = [];
    let processed = 0;
    for (const src of this.sources) {
      if (src.key.length === 0 || keys.indexOf(src.key) < 0) {
        continue;
      }
      await this.ensureSourceScriptInstalled(src, allowNetwork);
      if (JsEngineBridge.getInstance().isSourceStaged(src.key)) {
        nativeKeys.push(src.key);
      }
      processed++;
      if (processed % 2 === 0) {
        await ComicSourceService.yieldToUi();
      }
    }
    await JsEngineBridge.getInstance().registerSourcesToNative(nativeKeys);
    await this.syncExplorePagesFromSources();
  }

  /** 从沙箱目录扫描 .js 到 staged（不编译 QuickJS） */
  async loadStagedScriptsFromDisk(): Promise<void> {
    await JsEngineBridge.getInstance().loadCachedSourcesFromDiskAsync();
  }

  static parseIndexFromJson(json: string): ComicSourceInfo[] {
    return ComicSourceService.parseIndexJson(json);
  }

  private static parseIndexJson(json: string): ComicSourceInfo[] {
    const list: ComicSourceInfo[] = [];
    try {
      const parsed = JSON.parse(json) as Object;
      let arr: Array<Record<string, string>> = [];
      if (Array.isArray(parsed)) {
        arr = parsed as Array<Record<string, string>>;
      } else if (parsed !== null && typeof parsed === 'object') {
        const data = parsed as Record<string, Object>;
        if (Array.isArray(data['sources'])) {
          arr = data['sources'] as Array<Record<string, string>>;
        }
      }
      for (const item of arr) {
        const info = new ComicSourceInfo();
        info.key = item['key'] ?? '';
        info.name = item['name'] ?? info.key;
        info.version = item['version'] ?? '';
        info.description = item['description'] ?? '';
        info.url = item['url'] ?? '';
        info.scriptFile = item['fileName'] ?? `${info.key}.js`;
        info.enabled = true;
        if (info.key.length > 0) {
          list.push(info);
        }
      }
    } catch (e) {
      console.error(`[ComicSourceService] parse index failed: ${e}`);
    }
    return list;
  }

  private async readBundledIndexJson(): Promise<string> {
    return this.readBundledRawFile(AppConstants.BUNDLED_SOURCES_INDEX);
  }

  private async readBundledRawFile(relativePath: string): Promise<string> {
    if (!this.appContext) {
      return '';
    }
    try {
      const buf = await this.appContext.resourceManager.getRawFileContent(relativePath);
      return ComicSourceService.bytesToUtf8(new Uint8Array(buf));
    } catch (_e) {
      return '';
    }
  }

  private static bytesToUtf8(bytes: Uint8Array): string {
    return ComicSourceService.utf8Decoder.decodeToString(bytes);
  }

  private resolveScriptUrl(src: ComicSourceInfo): string {
    const scriptName = src.scriptFile.length > 0 ? src.scriptFile : `${src.key}.js`;
    if (src.url.length > 0 && src.url.endsWith('.js')) {
      return src.url;
    }
    return `${AppConstants.CONFIG_CDN_BASE}/${scriptName}`;
  }

  private sandboxScriptPath(sourceKey: string): string {
    return `${this.sourcesPath}/${sourceKey}.js`;
  }

  private static yieldToUi(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 16);
    });
  }

  private isScriptOnDisk(sourceKey: string): boolean {
    return FileIoUtil.existsSync(this.sandboxScriptPath(sourceKey));
  }

  private writeScriptToSandbox(sourceKey: string, script: string): void {
    const dest = this.sandboxScriptPath(sourceKey);
    const file = fileIo.openSync(dest,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const bytes = new Uint8Array(script.length);
    for (let i = 0; i < script.length; i++) {
      bytes[i] = script.charCodeAt(i) & 0xff;
    }
    fileIo.writeSync(file.fd, bytes.buffer);
    fileIo.closeSync(file.fd);
  }

  /** 确保单个图源已写入沙箱并注册到 QuickJS */
  private async ensureSourceScriptInstalled(src: ComicSourceInfo, allowNetwork: boolean = true): Promise<void> {
    if (JsEngineBridge.getInstance().isSourceStaged(src.key)) {
      return;
    }
    if (this.isScriptOnDisk(src.key)) {
      const script = JsEngineBridge.getInstance().readCachedSourceScript(src.key, this.sourcesPath);
      if (script.length > 0) {
        JsEngineBridge.getInstance().stageSourceScript(src.key, script);
      }
      return;
    }
    const scriptName = src.scriptFile.length > 0 ? src.scriptFile : `${src.key}.js`;
    let script = '';
    if (allowNetwork) {
      try {
        script = await HttpService.getInstance().get(this.resolveScriptUrl(src));
        console.info(`[ComicSourceService] downloaded ${src.key} from CDN`);
      } catch (e) {
        console.warn(`[ComicSourceService] CDN ${src.key} failed: ${e}`);
      }
    }
    if (script.length === 0) {
      const bundledPath = `${AppConstants.BUNDLED_SOURCES_DIR}/${scriptName}`;
      script = await this.readBundledRawFile(bundledPath);
      if (script.length > 0) {
        console.info(`[ComicSourceService] loaded bundled ${scriptName}`);
      }
    }
    if (script.length === 0) {
      console.warn(`[ComicSourceService] no script for ${src.key}`);
      return;
    }
    this.writeScriptToSandbox(src.key, script);
    JsEngineBridge.getInstance().stageSourceScript(src.key, script);
  }

  /**
   * 对齐上游 _addAllPagesWithComicSource：新装入图源后合并 explore_pages。
   */
  private async syncExplorePagesFromSources(): Promise<void> {
    const titles = await this.listExplorePageTitles();
    if (titles.length === 0) {
      return;
    }
    const settings = AppDataService.getInstance().settings;
    const merged: string[] = [...settings.explorePages];
    let changed = false;
    for (let i = 0; i < titles.length; i++) {
      if (merged.indexOf(titles[i]) < 0) {
        merged.push(titles[i]);
        changed = true;
      }
    }
    if (changed) {
      settings.explorePages = merged;
      AppDataService.getInstance().save();
      console.info(`[ComicSourceService] explore_pages synced (${merged.length} tabs)`);
    }
  }

  getCachedScriptCount(): number {
    return JsEngineBridge.getInstance().getStagedSourceKeys().length;
  }

  isSourceCached(key: string): boolean {
    return JsEngineBridge.getInstance().isSourceStaged(key);
  }

  async loadExplore(sourceKey: string): Promise<ExploreSection[]> {
    return JsEngineBridge.getInstance().invokeExplore(sourceKey);
  }

  async listExplorePageTitles(): Promise<string[]> {
    await this.ensureEngineReady();
    return JsEngineBridge.getInstance().invokeListExplorePageTitles();
  }

  /** 过滤设置中仍存在于已缓存源里的 explore 页标题 */
  async getConfiguredExplorePages(): Promise<string[]> {
    const available = await this.listExplorePageTitles();
    const configured = AppDataService.getInstance().settings.explorePages;
    if (configured.length === 0) {
      return [];
    }
    return configured.filter((t: string) => available.indexOf(t) >= 0);
  }

  async loadExploreByTitle(title: string, page: number = 1): Promise<ExplorePageLoadResult | null> {
    return JsEngineBridge.getInstance().invokeExploreByTitle(title, page);
  }

  isSourceInAggregatedSearch(sourceKey: string): boolean {
    const configured = AppDataService.getInstance().settings.searchSources;
    if (configured.length === 0) {
      return true;
    }
    return configured.indexOf(sourceKey) >= 0;
  }

  async getSearchableSourceKeysForSettings(): Promise<string[]> {
    const keys = await JsEngineBridge.getInstance().invokeSearchableSourceKeys();
    return keys.filter((k: string) => this.isSourceCached(k));
  }

  async toggleAggregatedSearchSource(sourceKey: string, enabled: boolean): Promise<void> {
    const all = await this.getSearchableSourceKeysForSettings();
    let configured = [...AppDataService.getInstance().settings.searchSources];
    if (configured.length === 0) {
      configured = [...all];
    }
    const idx = configured.indexOf(sourceKey);
    if (enabled && idx < 0) {
      configured.push(sourceKey);
    } else if (!enabled && idx >= 0) {
      configured.splice(idx, 1);
    }
    const stillAll = all.length > 0 && all.every((k: string) => configured.indexOf(k) >= 0);
    AppDataService.getInstance().settings.searchSources = stillAll ? [] : configured;
    AppDataService.getInstance().save();
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

  async getCategories(sourceKey: string): Promise<CategoryItem[]> {
    await this.ensureEngineReady();
    return JsEngineBridge.getInstance().invokeCategories(sourceKey);
  }

  async loadCategoryComics(sourceKey: string, item: CategoryItem, page: number): Promise<CategoryComicsResult> {
    return JsEngineBridge.getInstance().invokeCategoryComics(sourceKey, item, page);
  }

  getSourceByKey(key: string): ComicSourceInfo | undefined {
    return this.sources.find((s: ComicSourceInfo) => s.key === key);
  }

  isSourceLogged(sourceKey: string): boolean {
    return ComicSourceDataService.getInstance().isLogged(sourceKey);
  }

  resolveLoginUrl(sourceKey: string): string {
    const src = this.getSourceByKey(sourceKey);
    if (src && src.url.length > 0) {
      return src.url;
    }
    const scriptName = src && src.scriptFile.length > 0 ? src.scriptFile : `${sourceKey}.js`;
    return `${AppConstants.CONFIG_CDN_BASE}/${scriptName}`;
  }

  async getAggregatedSearchSourceKeys(): Promise<string[]> {
    const searchable = await JsEngineBridge.getInstance().invokeSearchableSourceKeys();
    const configured = AppDataService.getInstance().settings.searchSources;
    let keys = searchable.filter((k: string) => this.isSourceCached(k));
    if (configured.length > 0) {
      keys = keys.filter((k: string) => configured.indexOf(k) >= 0);
    }
    return keys;
  }

  async searchOneSource(sourceKey: string, keyword: string): Promise<Comic[]> {
    return JsEngineBridge.getInstance().invokeSearch(sourceKey, keyword);
  }

  async listRankingPages(): Promise<RankingPageInfo[]> {
    await this.ensureEngineReady();
    return JsEngineBridge.getInstance().invokeListRankingPages();
  }

  async loadRankingComics(sourceKey: string, option: string, page: number): Promise<CategoryComicsResult> {
    return JsEngineBridge.getInstance().invokeRankingComics(sourceKey, option, page);
  }

  getAvailableUpdates(): Map<string, string> {
    return this.availableUpdates;
  }

  getPendingVersion(sourceKey: string): string {
    return this.availableUpdates.get(sourceKey) ?? '';
  }

  getContext(): common.UIAbilityContext | undefined {
    return this.appContext;
  }

  getSourcesPath(): string {
    return this.sourcesPath;
  }

  /** 已装入 QuickJS 的漫画源列表（对齐上游 ComicSource.all） */
  async getInstalledSources(): Promise<InstalledComicSource[]> {
    const bridge = JsEngineBridge.getInstance();
    const list = await bridge.invokeAllInstalledMeta();
    for (let i = 0; i < list.length; i++) {
      const pending = this.availableUpdates.get(list[i].key);
      if (pending) {
        list[i].pendingVersion = pending;
      }
    }
    return list;
  }

  isKeyInstalled(key: string): boolean {
    return JsEngineBridge.getInstance().isSourceLoadedInNative(key);
  }

  async getSourceSettings(sourceKey: string): Promise<SourceSettingDef[]> {
    await this.ensureSourceReady(sourceKey);
    return JsEngineBridge.getInstance().invokeSourceSettings(sourceKey);
  }

  /**
   * 确保图源脚本已编译进 QuickJS（settings/account/login 依赖 ComicSource.sources）。
   */
  async ensureSourceReady(sourceKey: string): Promise<boolean> {
    await this.ensureEngineReady();
    const bridge = JsEngineBridge.getInstance();
    if (!bridge.getStatus().runtimeReady) {
      return false;
    }
    if (!bridge.isSourceStaged(sourceKey)) {
      const diskScript = bridge.getStagedScriptContent(sourceKey);
      if (diskScript.length === 0) {
        return false;
      }
      bridge.stageSourceScript(sourceKey, diskScript);
    }
    if (bridge.isSourceLoadedInNative(sourceKey)) {
      return true;
    }
    await bridge.registerSourcesToNative([sourceKey]);
    if (bridge.isSourceLoadedInNative(sourceKey)) {
      return true;
    }
    const script = bridge.getStagedScriptContent(sourceKey);
    if (script.length === 0) {
      return false;
    }
    return await bridge.loadSourceScript(sourceKey, script);
  }

  async getSourceAccount(sourceKey: string): Promise<SourceAccountConfig | null> {
    if (!await this.ensureSourceReady(sourceKey)) {
      return null;
    }
    return JsEngineBridge.getInstance().invokeSourceAccount(sourceKey);
  }

  async runSettingCallback(sourceKey: string, settingKey: string): Promise<string> {
    return JsEngineBridge.getInstance().invokeSettingCallback(sourceKey, settingKey);
  }

  async loginWithPassword(sourceKey: string, username: string, password: string): Promise<string> {
    if (!await this.ensureSourceReady(sourceKey)) {
      return '漫画源引擎未就绪，请稍后重试';
    }
    const err = await JsEngineBridge.getInstance().invokeAccountLogin(sourceKey, username, password);
    if (err.length === 0) {
      ComicSourceDataService.getInstance().saveData(sourceKey, 'account', [username, password]);
    }
    return err;
  }

  /** 图源字符串翻译（settings 标题/选项） */
  async translateSourceText(sourceKey: string, text: string): Promise<string> {
    return JsEngineBridge.getInstance().invokeSourceTranslate(sourceKey, text);
  }

  /**
   * 重新登录 — 对齐上游 comic_source_page 重新登录 ListTile。
   * 优先使用已保存的 account 凭据，否则调用 JS account.reLogin。
   */
  async reLoginSource(sourceKey: string): Promise<string> {
    const account = ComicSourceDataService.getInstance().loadData(sourceKey, 'account');
    if (account !== null && Array.isArray(account) && account.length >= 2) {
      return this.loginWithPassword(sourceKey, `${account[0]}`, `${account[1]}`);
    }
    return JsEngineBridge.getInstance().invokeAccountReLogin(sourceKey);
  }

  openHelpDoc(): void {
    const url = 'https://github.com/venera-app/venera/blob/master/doc/comic_source.md';
    const ctx = this.appContext;
    if (!ctx) {
      return;
    }
    ctx.openLink(url, { appLinkingOnly: false }).catch((e: Error) => {
      console.error(`[ComicSourceService] openHelpDoc failed: ${e}`);
    });
  }

  async logoutSource(sourceKey: string): Promise<void> {
    ComicSourceDataService.getInstance().logout(sourceKey);
    const safeKey = JSON.stringify(sourceKey);
    const script = `(function(){var s=ComicSource.sources[${safeKey}];` +
      `if(s&&s.account&&typeof s.account.logout==='function')s.account.logout();})()`;
    await JsEngineBridge.getInstance().evaluateRaw(script);
  }

  /** 打开登录页 — 对齐上游 ListTile「登录」整行点击；失败时返回错误文案 */
  async openLoginPage(sourceKey: string, sourceName: string): Promise<string> {
    if (!await this.ensureSourceReady(sourceKey)) {
      return '漫画源尚未装入 QuickJS，请稍后重试';
    }
    const cfg = await this.getSourceAccount(sourceKey);
    if (cfg && cfg.loginWebsite.length > 0 && !cfg.hasPasswordLogin) {
      this.openSourceLoginWeb(sourceKey, sourceName, cfg.loginWebsite);
      return '';
    }
    router.pushUrl({
      url: 'pages/sources/SourcePasswordLoginPage',
      params: { sourceKey: sourceKey, sourceName: sourceName }
    });
    return '';
  }

  openSourceLoginWeb(sourceKey: string, sourceName: string, loginUrl?: string): void {
    const src = this.getSourceByKey(sourceKey);
    const url = loginUrl && loginUrl.length > 0 ? loginUrl : this.resolveLoginUrl(sourceKey);
    router.pushUrl({
      url: 'pages/sources/SourceLoginWebPage',
      params: {
        sourceKey: sourceKey,
        sourceName: src?.name ?? sourceName,
        loginUrl: url
      }
    });
  }

  openSourceLogin(sourceKey: string): void {
    const src = this.getSourceByKey(sourceKey);
    this.getSourceAccount(sourceKey).then((cfg) => {
      const loginUrl = cfg && cfg.loginWebsite.length > 0 ? cfg.loginWebsite : this.resolveLoginUrl(sourceKey);
      this.openSourceLoginWeb(sourceKey, src?.name ?? sourceKey, loginUrl);
    });
  }

  async openPasswordLogin(sourceKey: string, sourceName: string): Promise<string> {
    return this.openLoginPage(sourceKey, sourceName);
  }

  private writeScriptFile(_fileName: string, script: string, sourceKey: string): string {
    const dest = `${this.sourcesPath}/${sourceKey}.js`;
    const file = fileIo.openSync(dest,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const bytes = new Uint8Array(script.length);
    for (let i = 0; i < script.length; i++) {
      bytes[i] = script.charCodeAt(i) & 0xff;
    }
    fileIo.writeSync(file.fd, bytes.buffer);
    fileIo.closeSync(file.fd);
    return dest;
  }

  async addSourceFromScript(script: string, fileName: string): Promise<string> {
    if (SourceScriptUtil.extractClassName(script).length === 0) {
      return '无效的漫画源脚本（需 class X extends ComicSource）';
    }
    await this.ensureEngineReady();
    const meta = await JsEngineBridge.getInstance().parseScriptMeta(script);
    if (!meta || meta.key.length === 0 || meta.name.length === 0) {
      if (!JsEngineBridge.getInstance().getStatus().runtimeReady) {
        return '漫画源引擎未就绪，请稍后重试';
      }
      return '无法解析漫画源（缺少 name 或 key）';
    }
    if (!/^[a-zA-Z0-9_]+$/.test(meta.key)) {
      return `key(${meta.key}) 仅允许字母数字下划线`;
    }
    if (JsEngineBridge.getInstance().isSourceStaged(meta.key)) {
      return `key(${meta.key}) 已存在`;
    }
    meta.filePath = this.writeScriptFile(fileName, script, meta.key);
    const ok = await JsEngineBridge.getInstance().loadSourceScript(meta.key, script);
    if (!ok) {
      FileIoUtil.deleteRecursive(meta.filePath);
      JsEngineBridge.getInstance().removeStagedSource(meta.key);
      return 'QuickJS 加载失败';
    }
    await this.mergePagesForSource(meta.key);
    const idx = this.sources.findIndex((s: ComicSourceInfo) => s.key === meta.key);
    if (idx < 0) {
      const info = new ComicSourceInfo();
      info.key = meta.key;
      info.name = meta.name;
      info.version = meta.version;
      info.url = meta.url;
      info.scriptFile = `${meta.key}.js`;
      info.enabled = true;
      this.sources.push(info);
    }
    return '';
  }

  async addSourceFromUrl(url: string): Promise<string> {
    if (url.trim().length === 0) {
      return 'URL 为空';
    }
    const trimmed = url.trim();
    const parts = trimmed.split('/').filter((p: string) => p.length > 0);
    const fileName = parts.length > 0 ? parts[parts.length - 1] : 'source.js';
    let script = '';
    try {
      script = await HttpService.getInstance().get(trimmed);
    } catch (e) {
      return `下载失败: ${e}`;
    }
    return this.addSourceFromScript(script, fileName);
  }

  async removeSource(sourceKey: string): Promise<void> {
    JsEngineBridge.getInstance().removeStagedSource(sourceKey);
    ComicSourceDataService.getInstance().clearSourceData(sourceKey);
    await JsEngineBridge.getInstance().reloadAllSourcesToNative();
    await this.validatePages();
  }

  async updateSource(sourceKey: string): Promise<string> {
    const meta = await JsEngineBridge.getInstance().invokeSourceMeta(sourceKey);
    if (!meta || meta.url.length === 0 || !meta.url.includes('://')) {
      return '无效的更新 URL';
    }
    let script = '';
    try {
      script = await HttpService.getInstance().get(meta.url);
    } catch (e) {
      return `更新失败: ${e}`;
    }
    JsEngineBridge.getInstance().removeStagedSource(sourceKey);
    this.writeScriptFile(`${sourceKey}.js`, script, sourceKey);
    const ok = await JsEngineBridge.getInstance().loadSourceScript(sourceKey, script);
    if (!ok) {
      return '重新加载失败';
    }
    this.availableUpdates.delete(sourceKey);
    await this.mergePagesForSource(sourceKey);
    return '';
  }

  /**
   * 检查 index 更新 — 对齐上游 ComicSourcePage.checkComicSourceUpdate。
   * @returns -1 网络错误，0 无更新，>0 可更新数量
   */
  async checkComicSourceUpdates(): Promise<number> {
    const installed = await this.getInstalledSources();
    if (installed.length === 0) {
      return 0;
    }
    const listUrl = AppDataService.getInstance().settings.comicSourceListUrl.length > 0 ?
      AppDataService.getInstance().settings.comicSourceListUrl : AppConstants.CONFIG_INDEX_URL;
    let json = '';
    try {
      json = await HttpService.getInstance().get(listUrl);
    } catch (_e) {
      return -1;
    }
    const indexList = ComicSourceService.parseIndexJson(json);
    const versions = new Map<string, string>();
    for (let i = 0; i < indexList.length; i++) {
      versions.set(indexList[i].key, indexList[i].version);
    }
    this.availableUpdates.clear();
    let count = 0;
    for (let i = 0; i < installed.length; i++) {
      const inst = installed[i];
      const remoteVer = versions.get(inst.key);
      if (remoteVer && SemVerUtil.isGreater(remoteVer, inst.version)) {
        this.availableUpdates.set(inst.key, remoteVer);
        count++;
      }
    }
    return count;
  }

  async updateAllAvailable(): Promise<string> {
    const keys = Array.from(this.availableUpdates.keys());
    for (let i = 0; i < keys.length; i++) {
      const err = await this.updateSource(keys[i]);
      if (err.length > 0) {
        return err;
      }
    }
    return '';
  }

  resolveIndexScriptUrl(entry: ComicSourceInfo): string {
    if (entry.url.length > 0 && entry.url.endsWith('.js')) {
      return entry.url;
    }
    const listUrl = AppDataService.getInstance().settings.comicSourceListUrl;
    const fileName = entry.scriptFile.length > 0 ? entry.scriptFile : `${entry.key}.js`;
    if (listUrl.includes('/')) {
      const base = listUrl.substring(0, listUrl.lastIndexOf('/') + 1);
      return `${base}${fileName}`;
    }
    return `${AppConstants.CONFIG_CDN_BASE}/${fileName}`;
  }

  /** 对齐上游 _addAllPagesWithComicSource */
  private async mergePagesForSource(sourceKey: string): Promise<void> {
    const rawObj = await JsEngineBridge.getInstance().invokeSourcePageKeys(sourceKey);
    if (!rawObj || typeof rawObj !== 'object') {
      return;
    }
    const raw = rawObj as Record<string, Object>;
    const settings = AppDataService.getInstance().settings;
    const explore = raw['explore'];
    if (Array.isArray(explore)) {
      const titles = explore as string[];
      let changed = false;
      for (let i = 0; i < titles.length; i++) {
        if (settings.explorePages.indexOf(titles[i]) < 0) {
          settings.explorePages.push(titles[i]);
          changed = true;
        }
      }
      if (changed) {
        AppDataService.getInstance().save();
      }
    }
    const catKey = `${raw['category'] ?? ''}`;
    if (catKey.length > 0 && settings.categoryPages.indexOf(catKey) < 0) {
      settings.categoryPages.push(catKey);
      await AppDataService.getInstance().save();
    }
    const favKey = `${raw['favorite'] ?? ''}`;
    if (favKey.length > 0 && settings.networkFavorites.indexOf(favKey) < 0) {
      settings.networkFavorites.push(favKey);
      await AppDataService.getInstance().save();
    }
    if (raw['search'] === true && settings.searchSources.indexOf(sourceKey) < 0) {
      const searchable = await this.getSearchableSourceKeysForSettings();
      if (searchable.indexOf(sourceKey) < 0) {
        settings.searchSources.push(sourceKey);
        await AppDataService.getInstance().save();
      }
    }
    await this.syncExplorePagesFromSources();
  }

  /** 对齐上游 _validatePages */
  async validatePages(): Promise<void> {
    const settings = AppDataService.getInstance().settings;
    const exploreAvail = await JsEngineBridge.getInstance().invokeListExplorePageTitles();
    const installed = await this.getInstalledSources();
    const categoryKeys: string[] = [];
    const favoriteKeys: string[] = [];
    for (let i = 0; i < installed.length; i++) {
      const rawObj = await JsEngineBridge.getInstance().invokeSourcePageKeys(installed[i].key);
      if (!rawObj || typeof rawObj !== 'object') {
        continue;
      }
      const raw = rawObj as Record<string, Object>;
      const cat = `${raw['category'] ?? ''}`;
      if (cat.length > 0) {
        categoryKeys.push(cat);
      }
      const fav = `${raw['favorite'] ?? ''}`;
      if (fav.length > 0) {
        favoriteKeys.push(fav);
      }
    }
    settings.explorePages = settings.explorePages.filter((t: string) => exploreAvail.indexOf(t) >= 0);
    settings.categoryPages = settings.categoryPages.filter((k: string) => categoryKeys.indexOf(k) >= 0);
    settings.networkFavorites =
      settings.networkFavorites.filter((k: string) => favoriteKeys.indexOf(k) >= 0);
    await AppDataService.getInstance().save();
  }

  readScriptContent(sourceKey: string): string {
    return JsEngineBridge.getInstance().readCachedSourceScript(sourceKey, this.sourcesPath);
  }

  writeScriptContent(sourceKey: string, content: string): void {
    this.writeScriptFile(`${sourceKey}.js`, content, sourceKey);
    JsEngineBridge.getInstance().loadSourceScript(sourceKey, content);
  }

  async reloadAfterEdit(sourceKey: string): Promise<void> {
    const script = this.readScriptContent(sourceKey);
    await JsEngineBridge.getInstance().loadSourceScript(sourceKey, script);
    await this.mergePagesForSource(sourceKey);
  }
}
