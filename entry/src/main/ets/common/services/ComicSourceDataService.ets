import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppConstants } from '../constants/AppConstants';

/**
 * 漫画源持久化数据 — 对应上游 ComicSource.data / saveData。
 * 每源一个 JSON 文件，供 init.js load_data / save_data 使用。
 */
export class ComicSourceDataService {
  private static instance: ComicSourceDataService;
  private dataRoot: string = '';

  static getInstance(): ComicSourceDataService {
    if (!ComicSourceDataService.instance) {
      ComicSourceDataService.instance = new ComicSourceDataService();
    }
    return ComicSourceDataService.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.dataRoot = `${context.filesDir}/${AppConstants.COMIC_SOURCES_DIR}/data`;
    try {
      fileIo.mkdirSync(this.dataRoot, true);
    } catch (_e) {
      // exists
    }
  }

  private filePath(sourceKey: string): string {
    return `${this.dataRoot}/${sourceKey}.json`;
  }

  private readStore(sourceKey: string): Record<string, Object> {
    try {
      const path = this.filePath(sourceKey);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      const bytes = new Uint8Array(buf);
      let text = '';
      for (let i = 0; i < bytes.length; i++) {
        text += String.fromCharCode(bytes[i]);
      }
      return JSON.parse(text) as Record<string, Object>;
    } catch (_e) {
      return {};
    }
  }

  private writeStore(sourceKey: string, store: Record<string, Object>): void {
    const path = this.filePath(sourceKey);
    const text = JSON.stringify(store);
    const bytes = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) {
      bytes[i] = text.charCodeAt(i) & 0xff;
    }
    const file = fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, bytes.buffer);
    fileIo.closeSync(file.fd);
  }

  loadData(sourceKey: string, dataKey: string): Object | null {
    if (sourceKey.length === 0 || dataKey.length === 0) {
      return null;
    }
    const store = this.readStore(sourceKey);
    const val = store[dataKey];
    return val === undefined ? null : val;
  }

  loadSetting(sourceKey: string, settingKey: string): Object | null {
    const setting = this.loadData(sourceKey, 'settings');
    if (setting === null) {
      return null;
    }
    const store = setting as Record<string, Object>;
    const val = store[settingKey];
    return val === undefined ? null : val;
  }

  isLogged(sourceKey: string): boolean {
    const token = this.loadData(sourceKey, 'token');
    if (token === null) {
      return false;
    }
    if (typeof token === 'string') {
      return token.length > 0;
    }
    return true;
  }

  saveData(sourceKey: string, dataKey: string, data: Object | undefined): void {
    if (sourceKey.length === 0 || dataKey.length === 0 || dataKey === 'setting') {
      return;
    }
    if (data === undefined || data === null) {
      this.deleteData(sourceKey, dataKey);
      return;
    }
    const store = this.readStore(sourceKey);
    store[dataKey] = data;
    this.writeStore(sourceKey, store);
  }

  deleteData(sourceKey: string, dataKey: string): void {
    if (sourceKey.length === 0 || dataKey.length === 0) {
      return;
    }
    const store = this.readStore(sourceKey);
    const copy: Record<string, Object> = {};
    const keys = Object.keys(store);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k !== dataKey) {
        copy[k] = store[k];
      }
    }
    this.writeStore(sourceKey, copy);
  }
}
