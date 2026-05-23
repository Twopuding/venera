/**
 * Application constants aligned with upstream Venera paths and defaults.
 */
export class AppConstants {
  static readonly APP_DATA_FILE: string = 'appdata.json';
  static readonly COMIC_SOURCES_DIR: string = 'comic_sources';
  static readonly LOCAL_COMICS_DIR: string = 'comics';
  static readonly DOWNLOADS_DIR: string = 'downloads';
  static readonly COOKIES_DB: string = 'cookies.db';
  static readonly CONFIG_INDEX_URL: string =
    'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json';
  /** rawfile 内置图源目录（scripts/fetch-comic-sources.ps1 同步 venera-configs） */
  static readonly BUNDLED_SOURCES_DIR: string = 'comic_sources';
  static readonly BUNDLED_SOURCES_INDEX: string = 'comic_sources/index.json';
  static readonly CONFIG_CDN_BASE: string =
    'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main';
  static readonly UPSTREAM_VERSION: string = '1.6.3';
  static readonly HARMONY_VERSION: string = '1.0.0';
  static readonly MIN_API_VERSION: number = 23;
  /** 首次启动默认装入的漫画源 key（Picacg / 绅士漫画 wnacg / 禁漫天堂 jm） */
  static readonly DEFAULT_SOURCE_KEYS: string[] = ['picacg', 'wnacg', 'jm'];
}
