import { common } from '@kit.AbilityKit';
import { AppDataService } from './AppDataService';

/**
 * EhTag 标签翻译（API 23 rawfile/assets/tags_tw.json）。
 * 在设置开启「标签翻译」时对标题/副标题中的 tag 片段做本地化。
 */
/** 标签搜索建议项（对齐上游 Pair<String, TranslationType>） */
export interface TagSuggestion {
  tag: string;
  namespace: string;
}

export class TagTranslationService {
  private static loaded: boolean = false;
  private static loading: boolean = false;
  private static tagMap: Record<string, Record<string, string>> = {};

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (TagTranslationService.loaded || TagTranslationService.loading) {
      return;
    }
    if (!AppDataService.getInstance().settings.enableTranslation) {
      return;
    }
    TagTranslationService.loading = true;
    try {
      const buf = await context.resourceManager.getRawFileContent('assets/tags_tw.json');
      const bytes = new Uint8Array(buf);
      let text = '';
      for (let i = 0; i < bytes.length; i++) {
        text += String.fromCharCode(bytes[i]);
      }
      const root = JSON.parse(text) as Record<string, Object>;
      TagTranslationService.tagMap = TagTranslationService.flattenTagRoot(root);
      TagTranslationService.loaded = true;
      console.info('[TagTranslationService] EhTag tags loaded');
    } catch (e) {
      console.warn(`[TagTranslationService] load failed: ${e}`);
    } finally {
      TagTranslationService.loading = false;
    }
  }

  static isEnabled(): boolean {
    return AppDataService.getInstance().settings.enableTranslation && TagTranslationService.loaded;
  }

  /** 翻译单条 tag，如 `female:sole female` */
  static translateTag(raw: string): string {
    if (!TagTranslationService.isEnabled() || raw.length === 0) {
      return raw;
    }
    const colon = raw.indexOf(':');
    if (colon <= 0) {
      return raw;
    }
    const ns = raw.substring(0, colon).trim();
    const name = raw.substring(colon + 1).trim();
    const bucket = TagTranslationService.tagMap[ns];
    if (!bucket) {
      return raw;
    }
    const hit = bucket[name];
    return hit ? `${ns}:${hit}` : raw;
  }

  /** 翻译标题中空格分隔的 tag 列表 */
  static translateTagLine(line: string): string {
    if (!TagTranslationService.isEnabled() || line.length === 0) {
      return line;
    }
    const parts = line.split(/\s+/);
    const out: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      if (p.indexOf(':') > 0) {
        out.push(TagTranslationService.translateTag(p));
      } else {
        out.push(p);
      }
    }
    return out.join(' ');
  }

  static hasTagData(): boolean {
    return TagTranslationService.loaded && Object.keys(TagTranslationService.tagMap).length > 0;
  }

  /** 对齐 upstream TagsTranslation.translationTagWithNamespace */
  static translationTagWithNamespace(text: string, namespace: string): string {
    if (!TagTranslationService.hasTagData()) {
      return text;
    }
    let key = text.toLowerCase();
    if (key !== 'reclass' && key.endsWith('s')) {
      key = key.substring(0, key.length - 1);
    }
    const bucket = TagTranslationService.tagMap[namespace];
    if (!bucket) {
      return text;
    }
    return bucket[key] ?? text;
  }

  /**
   * 按输入末尾 token 匹配 EhTag 标签（对齐 upstream findSuggestions）。
   */
  static findTagSuggestions(queryToken: string, maxCount: number = 100): TagSuggestion[] {
    const out: TagSuggestion[] = [];
    if (!TagTranslationService.hasTagData()) {
      return out;
    }
    const text = queryToken.trim();
    if (text.length === 0) {
      return out;
    }
    const namespaces = Object.keys(TagTranslationService.tagMap);
    for (let ni = 0; ni < namespaces.length; ni++) {
      const ns = namespaces[ni];
      const bucket = TagTranslationService.tagMap[ns];
      const keys = Object.keys(bucket);
      for (let ki = 0; ki < keys.length; ki++) {
        if (out.length >= maxCount) {
          return out;
        }
        const key = keys[ki];
        const value = bucket[key];
        if (TagTranslationService.matchSuggestionToken(text, key, value)) {
          out.push({ tag: key, namespace: ns });
        }
      }
    }
    return out;
  }

  private static matchSuggestionToken(text: string, key: string, value: string): boolean {
    if (key.length >= text.length && key.substring(0, text.length) === text) {
      return true;
    }
    if (key.indexOf(' ') >= 0) {
      const last = key.split(' ').pop() ?? '';
      if (last.length >= text.length && last.substring(0, text.length) === text) {
        return true;
      }
    }
    if (value.length >= text.length && value.indexOf(text) >= 0) {
      return true;
    }
    return false;
  }

  private static flattenTagRoot(root: Record<string, Object>): Record<string, Record<string, string>> {
    const out: Record<string, Record<string, string>> = {};
    const keys = Object.keys(root);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const val = root[key];
      if (val !== null && typeof val === 'object' && !Array.isArray(val)) {
        const inner = val as Record<string, string>;
        const bucket: Record<string, string> = {};
        const innerKeys = Object.keys(inner);
        for (let j = 0; j < innerKeys.length; j++) {
          const ik = innerKeys[j];
          bucket[ik] = `${inner[ik]}`;
        }
        out[key] = bucket;
      }
    }
    return out;
  }
}
