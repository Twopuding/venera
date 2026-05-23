import { util } from '@kit.ArkTS';
import { HttpService } from './HttpService';
import { AppDataService, AppSettings } from './AppDataService';
import { FavoritesService, FavoriteEntry } from './FavoritesService';
import { HistoryService } from './HistoryService';
import { ReadingHistoryEntry } from '../models/ComicModels';

const SYNC_FILE_NAME: string = 'venera_sync.json';

export interface WebDavSyncResult {
  ok: boolean;
  message: string;
}

interface WebDavSyncPayload {
  version: number;
  updatedAt: number;
  favorites: FavoriteEntry[];
  history: ReadingHistoryEntry[];
  settings: AppSettings;
}

/**
 * WebDAV 数据同步（API 23 NetworkKit PUT/GET + Basic 认证）。
 * 对齐上游 data_sync：上传/拉取收藏、历史与设置 JSON。
 */
export class WebDavSyncService {
  private static base64 = new util.Base64Helper();

  private static normalizeBaseUrl(url: string): string {
    let u = url.trim();
    if (u.length === 0) {
      return '';
    }
    if (!u.endsWith('/')) {
      u = `${u}/`;
    }
    return u;
  }

  private static authHeader(username: string, password: string): Record<string, string> {
    const cred = `${username}:${password}`;
    const bytes = new util.TextEncoder().encode(cred);
    return { 'Authorization': `Basic ${WebDavSyncService.base64.encodeToStringSync(bytes)}` };
  }

  private static syncFileUrl(baseUrl: string): string {
    return `${baseUrl}${SYNC_FILE_NAME}`;
  }

  private static buildPayload(): WebDavSyncPayload {
    const settings = AppDataService.getInstance().settings;
    return {
      version: 1,
      updatedAt: Date.now(),
      favorites: FavoritesService.getInstance().getAll(),
      history: HistoryService.getInstance().getEntries(),
      settings: {
        initialPage: settings.initialPage,
        themeMode: settings.themeMode,
        readerMode: settings.readerMode,
        proxy: settings.proxy,
        enableTranslation: settings.enableTranslation,
        webdavUrl: settings.webdavUrl,
        webdavUsername: settings.webdavUsername,
        webdavPassword: settings.webdavPassword,
        searchSources: settings.searchSources,
        explorePages: settings.explorePages,
        comicSourceListUrl: settings.comicSourceListUrl,
        categoryPages: settings.categoryPages,
        networkFavorites: settings.networkFavorites,
        defaultSearchTarget: settings.defaultSearchTarget,
        followUpdatesFolder: settings.followUpdatesFolder,
        autoAddLanguageFilter: settings.autoAddLanguageFilter,
        comicDisplayMode: settings.comicDisplayMode,
        comicTileScale: settings.comicTileScale,
        showFavoriteStatusOnTile: settings.showFavoriteStatusOnTile,
        showHistoryStatusOnTile: settings.showHistoryStatusOnTile,
        reverseChapterOrder: settings.reverseChapterOrder,
        blockedWords: settings.blockedWords,
        blockedCommentWords: settings.blockedCommentWords,
        comicListDisplayMode: settings.comicListDisplayMode
      }
    };
  }

  static async testConnection(): Promise<WebDavSyncResult> {
    const settings = AppDataService.getInstance().settings;
    const base = WebDavSyncService.normalizeBaseUrl(settings.webdavUrl);
    if (base.length === 0) {
      return { ok: false, message: '请先填写 WebDAV 目录 URL' };
    }
    try {
      const headers = WebDavSyncService.authHeader(settings.webdavUsername, settings.webdavPassword);
      headers['Content-Type'] = 'application/json';
      const res = await HttpService.getInstance().request({
        url: WebDavSyncService.syncFileUrl(base),
        method: 'HEAD',
        headers: headers
      });
      if (res.status === 200 || res.status === 404) {
        return { ok: true, message: res.status === 404 ? '连接成功（远端尚无同步文件）' : '连接成功' };
      }
      return { ok: false, message: `服务器响应 ${res.status}` };
    } catch (e) {
      return { ok: false, message: `连接失败：${e}` };
    }
  }

  static async upload(): Promise<WebDavSyncResult> {
    const settings = AppDataService.getInstance().settings;
    const base = WebDavSyncService.normalizeBaseUrl(settings.webdavUrl);
    if (base.length === 0) {
      return { ok: false, message: '请先填写 WebDAV 目录 URL' };
    }
    try {
      const headers = WebDavSyncService.authHeader(settings.webdavUsername, settings.webdavPassword);
      headers['Content-Type'] = 'application/json; charset=utf-8';
      const body = JSON.stringify(WebDavSyncService.buildPayload());
      const res = await HttpService.getInstance().putText(
        WebDavSyncService.syncFileUrl(base), body, headers);
      if (res.status >= 200 && res.status < 300) {
        return { ok: true, message: '数据已上传至 WebDAV' };
      }
      return { ok: false, message: `上传失败：HTTP ${res.status}` };
    } catch (e) {
      return { ok: false, message: `上传失败：${e}` };
    }
  }

  static async download(): Promise<WebDavSyncResult> {
    const settings = AppDataService.getInstance().settings;
    const base = WebDavSyncService.normalizeBaseUrl(settings.webdavUrl);
    if (base.length === 0) {
      return { ok: false, message: '请先填写 WebDAV 目录 URL' };
    }
    try {
      const headers = WebDavSyncService.authHeader(settings.webdavUsername, settings.webdavPassword);
      const json = await HttpService.getInstance().get(WebDavSyncService.syncFileUrl(base), headers);
      const payload = JSON.parse(json) as WebDavSyncPayload;
      await WebDavSyncService.applyPayload(payload);
      return { ok: true, message: '已从 WebDAV 合并数据' };
    } catch (e) {
      return { ok: false, message: `下载失败：${e}` };
    }
  }

  private static async applyPayload(payload: WebDavSyncPayload): Promise<void> {
    if (payload.favorites && Array.isArray(payload.favorites)) {
      await FavoritesService.getInstance().mergeFromRemote(payload.favorites);
    }
    if (payload.history && Array.isArray(payload.history)) {
      await HistoryService.getInstance().mergeFromRemote(payload.history);
    }
    if (payload.settings) {
      const local = AppDataService.getInstance().settings;
      local.readerMode = payload.settings.readerMode ?? local.readerMode;
      local.proxy = payload.settings.proxy ?? local.proxy;
      local.enableTranslation = payload.settings.enableTranslation ?? local.enableTranslation;
      local.initialPage = payload.settings.initialPage ?? local.initialPage;
      if (payload.settings.searchSources && Array.isArray(payload.settings.searchSources)) {
        local.searchSources = payload.settings.searchSources;
      }
      if (payload.settings.explorePages && Array.isArray(payload.settings.explorePages)) {
        local.explorePages = payload.settings.explorePages;
      }
      if (payload.settings.defaultSearchTarget !== undefined) {
        local.defaultSearchTarget = `${payload.settings.defaultSearchTarget}`;
      }
      if (payload.settings.autoAddLanguageFilter !== undefined) {
        local.autoAddLanguageFilter = `${payload.settings.autoAddLanguageFilter}`;
      }
      if (payload.settings.categoryPages && Array.isArray(payload.settings.categoryPages)) {
        local.categoryPages = payload.settings.categoryPages;
      }
      if (payload.settings.networkFavorites && Array.isArray(payload.settings.networkFavorites)) {
        local.networkFavorites = payload.settings.networkFavorites;
      }
      if (payload.settings.comicDisplayMode !== undefined) {
        local.comicDisplayMode = `${payload.settings.comicDisplayMode}`;
      }
      if (payload.settings.comicTileScale !== undefined) {
        local.comicTileScale = payload.settings.comicTileScale as number;
      }
      if (payload.settings.showFavoriteStatusOnTile !== undefined) {
        local.showFavoriteStatusOnTile = payload.settings.showFavoriteStatusOnTile as boolean;
      }
      if (payload.settings.showHistoryStatusOnTile !== undefined) {
        local.showHistoryStatusOnTile = payload.settings.showHistoryStatusOnTile as boolean;
      }
      if (payload.settings.reverseChapterOrder !== undefined) {
        local.reverseChapterOrder = payload.settings.reverseChapterOrder as boolean;
      }
      if (payload.settings.blockedWords && Array.isArray(payload.settings.blockedWords)) {
        local.blockedWords = payload.settings.blockedWords;
      }
      if (payload.settings.blockedCommentWords && Array.isArray(payload.settings.blockedCommentWords)) {
        local.blockedCommentWords = payload.settings.blockedCommentWords;
      }
      if (payload.settings.comicListDisplayMode !== undefined) {
        local.comicListDisplayMode = `${payload.settings.comicListDisplayMode}`;
      }
      await AppDataService.getInstance().save();
    }
  }
}
