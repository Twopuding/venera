import { AppDataService } from '../services/AppDataService';

/**
 * 搜索辅助 — 对齐 upstream search_page.dart / search_result_page.dart
 */
export class SearchUtil {
  /** 对齐 upstream checkAutoLanguage */
  static checkAutoLanguage(text: string, sourceKey: string): string {
    const setting = AppDataService.getInstance().settings.autoAddLanguageFilter;
    if (setting === 'none' || setting.length === 0) {
      return text;
    }
    const enabledSources = ['nhentai', 'ehentai'];
    if (enabledSources.indexOf(sourceKey) < 0) {
      return text;
    }
    if (text.indexOf('language:') >= 0) {
      return text;
    }
    return `${text} language:${setting}`;
  }

  static isHttpUrl(text: string): boolean {
    const t = text.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  static getLastToken(text: string): string {
    const parts = text.split(' ');
    return parts.length > 0 ? parts[parts.length - 1] : '';
  }

  static replaceLastToken(text: string, removeToken: string, insert: string): string {
    const trimmed = text.trimEnd();
    if (trimmed.endsWith(removeToken)) {
      return trimmed.substring(0, trimmed.length - removeToken.length) + insert;
    }
    const parts = text.split(' ');
    if (parts.length === 0) {
      return insert;
    }
    parts[parts.length - 1] = '';
    let base = parts.join(' ').trimEnd();
    if (base.length > 0 && !base.endsWith(' ')) {
      base += ' ';
    }
    return base + insert;
  }

  static removeTrailingToken(text: string, token: string): string {
    const words = text.split(' ');
    if (words.length >= 2) {
      const pair = `${words[words.length - 2]} ${words[words.length - 1]}`;
      if (pair === token) {
        return text.substring(0, text.length - pair.length).trimEnd();
      }
    }
    if (words.length > 0 && words[words.length - 1] === token) {
      words.pop();
      return words.join(' ').trimEnd();
    }
    return text;
  }

  static formatTagInsert(namespace: string, tag: string): string {
    let t = tag;
    if (t.indexOf(' ') >= 0) {
      t = `'${t}'`;
    }
    if (namespace.length > 0) {
      return `${namespace}:${t} `;
    }
    return `${t} `;
  }
}
