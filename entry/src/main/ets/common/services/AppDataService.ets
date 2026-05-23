import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppConstants } from '../constants/AppConstants';

export interface AppSettings {
  initialPage: number;
  themeMode: string;
  readerMode: string;
  proxy: string;
  enableTranslation: boolean;
  webdavUrl: string;
  webdavUsername: string;
  webdavPassword: string;
  /** 参与聚合搜索的源 key（对齐上游；空数组表示未配置/无参与源） */
  searchSources: string[];
  /** 发现 Tab 展示的 explore 页标题（对齐上游 explore_pages） */
  explorePages: string[];
  /** 官方图源 index.json URL（对齐上游 comicSourceListUrl） */
  comicSourceListUrl: string;
  /** 分类 Tab 启用的源 category key 列表 */
  categoryPages: string[];
  /** 网络收藏启用的源 favorite key 列表 */
  networkFavorites: string[];
  /** 默认搜索目标：图源 key 或 `_aggregated_` */
  defaultSearchTarget: string;
  /** 关注更新绑定的本地收藏夹名（对齐上游 followUpdatesFolder） */
  followUpdatesFolder: string;
  /** 搜索自动追加 language 过滤：none | chinese | english | japanese */
  autoAddLanguageFilter: string;
  /** 漫画块显示：detailed | brief — 对齐 upstream comicDisplayMode */
  comicDisplayMode: string;
  /** 漫画块缩放 0.5–1.5 — 对齐 upstream comicTileScale */
  comicTileScale: number;
  showFavoriteStatusOnTile: boolean;
  showHistoryStatusOnTile: boolean;
  reverseChapterOrder: boolean;
  blockedWords: string[];
  blockedCommentWords: string[];
  /** paging | continuous — 对齐 upstream comicListDisplayMode */
  comicListDisplayMode: string;
}

const DEFAULT_SETTINGS: AppSettings = {
  initialPage: 0,
  themeMode: 'system',
  readerMode: 'vertical',
  proxy: '',
  enableTranslation: true,
  webdavUrl: '',
  webdavUsername: '',
  webdavPassword: '',
  searchSources: [],
  explorePages: [],
  comicSourceListUrl: '',
  categoryPages: [],
  networkFavorites: [],
  defaultSearchTarget: '',
  followUpdatesFolder: '',
  autoAddLanguageFilter: 'none',
  comicDisplayMode: 'detailed',
  comicTileScale: 1.0,
  showFavoriteStatusOnTile: true,
  showHistoryStatusOnTile: false,
  reverseChapterOrder: false,
  blockedWords: [],
  blockedCommentWords: [],
  comicListDisplayMode: 'paging'
};

/**
 * Persistent settings — mirrors upstream Appdata / Settings.
 */
export class AppDataService {
  private static instance: AppDataService;
  private prefStore?: preferences.Preferences;
  settings: AppSettings = {
    initialPage: DEFAULT_SETTINGS.initialPage,
    themeMode: DEFAULT_SETTINGS.themeMode,
    readerMode: DEFAULT_SETTINGS.readerMode,
    proxy: DEFAULT_SETTINGS.proxy,
    enableTranslation: DEFAULT_SETTINGS.enableTranslation,
    webdavUrl: DEFAULT_SETTINGS.webdavUrl,
    webdavUsername: DEFAULT_SETTINGS.webdavUsername,
    webdavPassword: DEFAULT_SETTINGS.webdavPassword,
    searchSources: [],
    explorePages: [],
    comicSourceListUrl: '',
    categoryPages: [],
    networkFavorites: [],
    defaultSearchTarget: '',
    followUpdatesFolder: '',
    autoAddLanguageFilter: 'none',
    comicDisplayMode: DEFAULT_SETTINGS.comicDisplayMode,
    comicTileScale: DEFAULT_SETTINGS.comicTileScale,
    showFavoriteStatusOnTile: DEFAULT_SETTINGS.showFavoriteStatusOnTile,
    showHistoryStatusOnTile: DEFAULT_SETTINGS.showHistoryStatusOnTile,
    reverseChapterOrder: DEFAULT_SETTINGS.reverseChapterOrder,
    blockedWords: [],
    blockedCommentWords: [],
    comicListDisplayMode: DEFAULT_SETTINGS.comicListDisplayMode
  };
  searchHistory: string[] = [];
  /** 上次选中的收藏夹（对齐 upstream implicitData favoriteFolder） */
  favoriteFolderName: string = '';
  favoriteFolderIsNetwork: boolean = false;
  /** 从漫画源页跳转到分类 Tab 时预选源 key */
  pendingCategorySourceKey: string = '';
  private firstLaunchComplete: boolean = false;
  private settingsListeners: Array<() => void> = [];

  static getInstance(): AppDataService {
    if (!AppDataService.instance) {
      AppDataService.instance = new AppDataService();
    }
    return AppDataService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefStore = await preferences.getPreferences(context, 'venera_appdata');
    this.settings.initialPage = await this.prefStore.get('initialPage', 0) as number;
    this.settings.themeMode = await this.prefStore.get('themeMode', 'system') as string;
    this.settings.readerMode = await this.prefStore.get('readerMode', 'vertical') as string;
    this.settings.proxy = await this.prefStore.get('proxy', '') as string;
    this.settings.enableTranslation =
      await this.prefStore.get('enableTranslation', true) as boolean;
    this.settings.webdavUrl = await this.prefStore.get('webdavUrl', '') as string;
    this.settings.webdavUsername = await this.prefStore.get('webdavUsername', '') as string;
    this.settings.webdavPassword = await this.prefStore.get('webdavPassword', '') as string;
    const searchSourcesRaw = await this.prefStore.get('searchSources', '[]') as string;
    try {
      this.settings.searchSources = JSON.parse(searchSourcesRaw) as string[];
    } catch (_e) {
      this.settings.searchSources = [];
    }
    const explorePagesRaw = await this.prefStore.get('explorePages', '[]') as string;
    try {
      this.settings.explorePages = JSON.parse(explorePagesRaw) as string[];
    } catch (_e) {
      this.settings.explorePages = [];
    }
    this.settings.comicSourceListUrl =
      await this.prefStore.get('comicSourceListUrl', '') as string;
    if (this.settings.comicSourceListUrl.includes('git.nyne.dev')) {
      this.settings.comicSourceListUrl = AppConstants.CONFIG_INDEX_URL;
      await this.save();
    }
    const categoryPagesRaw = await this.prefStore.get('categoryPages', '[]') as string;
    try {
      this.settings.categoryPages = JSON.parse(categoryPagesRaw) as string[];
    } catch (_e) {
      this.settings.categoryPages = [];
    }
    this.settings.defaultSearchTarget =
      await this.prefStore.get('defaultSearchTarget', '') as string;
    const networkFavRaw = await this.prefStore.get('networkFavorites', '[]') as string;
    try {
      this.settings.networkFavorites = JSON.parse(networkFavRaw) as string[];
    } catch (_e) {
      this.settings.networkFavorites = [];
    }
    const historyRaw = await this.prefStore.get('searchHistory', '[]') as string;
    try {
      this.searchHistory = JSON.parse(historyRaw) as string[];
    } catch (_e) {
      this.searchHistory = [];
    }
    this.firstLaunchComplete = await this.prefStore.get('firstLaunchComplete', false) as boolean;
    this.settings.followUpdatesFolder =
      await this.prefStore.get('followUpdatesFolder', '') as string;
    this.settings.autoAddLanguageFilter =
      await this.prefStore.get('autoAddLanguageFilter', 'none') as string;
    this.settings.comicDisplayMode =
      await this.prefStore.get('comicDisplayMode', 'detailed') as string;
    this.settings.comicTileScale =
      await this.prefStore.get('comicTileScale', 1.0) as number;
    this.settings.showFavoriteStatusOnTile =
      await this.prefStore.get('showFavoriteStatusOnTile', true) as boolean;
    this.settings.showHistoryStatusOnTile =
      await this.prefStore.get('showHistoryStatusOnTile', false) as boolean;
    this.settings.reverseChapterOrder =
      await this.prefStore.get('reverseChapterOrder', false) as boolean;
    const blockedRaw = await this.prefStore.get('blockedWords', '[]') as string;
    try {
      this.settings.blockedWords = JSON.parse(blockedRaw) as string[];
    } catch (_e) {
      this.settings.blockedWords = [];
    }
    const blockedCommentRaw = await this.prefStore.get('blockedCommentWords', '[]') as string;
    try {
      this.settings.blockedCommentWords = JSON.parse(blockedCommentRaw) as string[];
    } catch (_e) {
      this.settings.blockedCommentWords = [];
    }
    this.settings.comicListDisplayMode =
      await this.prefStore.get('comicListDisplayMode', 'paging') as string;
    this.favoriteFolderName = await this.prefStore.get('favoriteFolderName', '') as string;
    this.favoriteFolderIsNetwork =
      await this.prefStore.get('favoriteFolderIsNetwork', false) as boolean;
  }

  isFirstLaunchComplete(): boolean {
    return this.firstLaunchComplete;
  }

  async markFirstLaunchComplete(): Promise<void> {
    this.firstLaunchComplete = true;
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put('firstLaunchComplete', true);
    await this.prefStore.flush();
  }

  onSettingsChange(listener: () => void): void {
    this.settingsListeners.push(listener);
  }

  private notifySettingsChange(): void {
    for (let i = 0; i < this.settingsListeners.length; i++) {
      this.settingsListeners[i]();
    }
  }

  async save(): Promise<void> {
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put('initialPage', this.settings.initialPage);
    await this.prefStore.put('themeMode', this.settings.themeMode);
    await this.prefStore.put('readerMode', this.settings.readerMode);
    await this.prefStore.put('proxy', this.settings.proxy);
    await this.prefStore.put('enableTranslation', this.settings.enableTranslation);
    await this.prefStore.put('webdavUrl', this.settings.webdavUrl);
    await this.prefStore.put('webdavUsername', this.settings.webdavUsername);
    await this.prefStore.put('webdavPassword', this.settings.webdavPassword);
    await this.prefStore.put('searchSources', JSON.stringify(this.settings.searchSources));
    await this.prefStore.put('explorePages', JSON.stringify(this.settings.explorePages));
    await this.prefStore.put('comicSourceListUrl', this.settings.comicSourceListUrl);
    await this.prefStore.put('categoryPages', JSON.stringify(this.settings.categoryPages));
    await this.prefStore.put('networkFavorites', JSON.stringify(this.settings.networkFavorites));
    await this.prefStore.put('defaultSearchTarget', this.settings.defaultSearchTarget);
    await this.prefStore.put('searchHistory', JSON.stringify(this.searchHistory));
    await this.prefStore.put('followUpdatesFolder', this.settings.followUpdatesFolder);
    await this.prefStore.put('autoAddLanguageFilter', this.settings.autoAddLanguageFilter);
    await this.prefStore.put('comicDisplayMode', this.settings.comicDisplayMode);
    await this.prefStore.put('comicTileScale', this.settings.comicTileScale);
    await this.prefStore.put('showFavoriteStatusOnTile', this.settings.showFavoriteStatusOnTile);
    await this.prefStore.put('showHistoryStatusOnTile', this.settings.showHistoryStatusOnTile);
    await this.prefStore.put('reverseChapterOrder', this.settings.reverseChapterOrder);
    await this.prefStore.put('blockedWords', JSON.stringify(this.settings.blockedWords));
    await this.prefStore.put('blockedCommentWords', JSON.stringify(this.settings.blockedCommentWords));
    await this.prefStore.put('comicListDisplayMode', this.settings.comicListDisplayMode);
    await this.prefStore.put('favoriteFolderName', this.favoriteFolderName);
    await this.prefStore.put('favoriteFolderIsNetwork', this.favoriteFolderIsNetwork);
    await this.prefStore.flush();
    this.notifySettingsChange();
  }

  addSearchHistory(keyword: string): void {
    const idx = this.searchHistory.indexOf(keyword);
    if (idx >= 0) {
      this.searchHistory.splice(idx, 1);
    }
    this.searchHistory.unshift(keyword);
    if (this.searchHistory.length > 50) {
      this.searchHistory.pop();
    }
    this.save();
  }

  removeSearchHistory(keyword: string): void {
    const idx = this.searchHistory.indexOf(keyword);
    if (idx >= 0) {
      this.searchHistory.splice(idx, 1);
      this.save();
    }
  }

  clearSearchHistory(): void {
    if (this.searchHistory.length === 0) {
      return;
    }
    this.searchHistory = [];
    this.save();
  }

  getDataRoot(): string {
    return AppConstants.LOCAL_COMICS_DIR;
  }
}
