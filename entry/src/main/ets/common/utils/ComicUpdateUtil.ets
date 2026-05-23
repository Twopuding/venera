import { Comic } from '../models/ComicModels';

/** 漫画更新时间解析 — 对齐 upstream Comic.findUpdateTime */
export class ComicUpdateUtil {
  static findUpdateTime(comic: Comic, tagsMap?: Record<string, string[]>): string | undefined {
    const direct = comic.updateTime;
    if (direct && direct.length > 0) {
      const v = ComicUpdateUtil.validateUpdateTime(direct);
      if (v) {
        return v;
      }
    }
    const namespaces = ['更新', '最後更新', '最后更新', 'update', 'last update'];
    if (tagsMap) {
      const keys = Object.keys(tagsMap);
      for (let i = 0; i < keys.length; i++) {
        const ns = keys[i].toLowerCase();
        if (namespaces.includes(ns) || namespaces.includes(keys[i])) {
          const vals = tagsMap[keys[i]];
          if (vals.length > 0) {
            const v = ComicUpdateUtil.validateUpdateTime(vals[0]);
            if (v) {
              return v;
            }
          }
        }
      }
    }
    if (comic.tags) {
      for (let i = 0; i < comic.tags.length; i++) {
        const tag = comic.tags[i];
        const colon = tag.indexOf(':');
        if (colon > 0) {
          const ns = tag.substring(0, colon).toLowerCase();
          if (namespaces.includes(ns)) {
            const v = ComicUpdateUtil.validateUpdateTime(tag.substring(colon + 1));
            if (v) {
              return v;
            }
          }
        }
      }
    }
    return undefined;
  }

  private static validateUpdateTime(time: string): string | undefined {
    let t = time.split(' ')[0];
    const segments = t.split('-');
    if (segments.length !== 3) {
      return undefined;
    }
    const year = parseInt(segments[0], 10);
    const month = parseInt(segments[1], 10);
    const day = parseInt(segments[2], 10);
    if (isNaN(year) || isNaN(month) || isNaN(day)) {
      return undefined;
    }
    if (year < 2000 || year > 3000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return undefined;
    }
    return `${year}-${month}-${day}`;
  }
}
