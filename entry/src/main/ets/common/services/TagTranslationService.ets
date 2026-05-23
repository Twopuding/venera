import { common } from '@kit.AbilityKit';
import { AppDataService } from './AppDataService';

/**
 * EhTag 标签翻译（API 23 rawfile/assets/tags_tw.json）。
 * 在设置开启「标签翻译」时对标题/副标题中的 tag 片段做本地化。
 */
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
