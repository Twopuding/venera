import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppConstants } from '../constants/AppConstants';

export interface AppSettings {
  initialPage: number;
  themeMode: string;
  readerMode: string;
  proxy: string;
  enableTranslation: boolean;
}

const DEFAULT_SETTINGS: AppSettings = {
  initialPage: 0,
  themeMode: 'system',
  readerMode: 'vertical',
  proxy: '',
  enableTranslation: true
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
    enableTranslation: DEFAULT_SETTINGS.enableTranslation
  };
  searchHistory: string[] = [];

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
    const historyRaw = await this.prefStore.get('searchHistory', '[]') as string;
    try {
      this.searchHistory = JSON.parse(historyRaw) as string[];
    } catch (_e) {
      this.searchHistory = [];
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
