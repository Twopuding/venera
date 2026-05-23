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
  /** 参与聚合搜索的源 key；空数组表示全部可搜索源 */
  searchSources: string[];
  /** 发现 Tab 展示的 explore 页标题（对齐上游 explore_pages） */
  explorePages: string[];
  /** 官方图源 index.json URL（对齐上游 comicSourceListUrl） */
  comicSourceListUrl: string;
  /** 分类 Tab 启用的源 category key 列表 */
  categoryPages: string[];
  /** 网络收藏启用的源 favorite key 列表 */
  networkFavorites: string[];
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
  networkFavorites: []
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
    networkFavorites: []
  };
  searchHistory: string[] = [];
  /** 从漫画源页跳转到分类 Tab 时预选源 key */
  pendingCategorySourceKey: string = '';
  private firstLaunchComplete: boolean = false;

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
    const categoryPagesRaw = await this.prefStore.get('categoryPages', '[]') as string;
    try {
      this.settings.categoryPages = JSON.parse(categoryPagesRaw) as string[];
    } catch (_e) {
      this.settings.categoryPages = [];
    }
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
    await this.prefStore.put('searchHistory', JSON.stringify(this.searchHistory));
    await this.prefStore.flush();
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

  getDataRoot(): string {
    return AppConstants.LOCAL_COMICS_DIR;
  }
}
