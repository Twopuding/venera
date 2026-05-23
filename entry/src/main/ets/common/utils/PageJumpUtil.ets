import { router } from '@kit.ArkUI';
import { CategoryItem } from '../models/ComicModels';

/**
 * 图源页面跳转目标 — 对齐 upstream PageJumpTarget (models.dart)
 */
export class PageJumpTarget {
  sourceKey: string = '';
  page: string = '';
  attributes: Record<string, string> = {};

  static parse(sourceKey: string, value: Object | null | undefined): PageJumpTarget | null {
    if (value === null || value === undefined) {
      return null;
    }
    const target = new PageJumpTarget();
    target.sourceKey = sourceKey;
    if (typeof value === 'string') {
      return PageJumpTarget.parseString(sourceKey, value);
    }
    if (typeof value !== 'object') {
      return null;
    }
    const map = value as Record<string, Object>;
    if (map['page'] !== undefined) {
      target.page = `${map['page'] ?? 'search'}`;
      target.attributes = PageJumpTarget.attrsFrom(map['attributes']);
      return target;
    }
    if (map['action'] !== undefined) {
      const action = `${map['action']}`;
      if (action === 'search') {
        target.page = 'search';
        PageJumpTarget.putAttr(target, 'text', `${map['keyword'] ?? ''}`);
        return target;
      }
      if (action === 'category') {
        target.page = 'category';
        PageJumpTarget.putAttr(target, 'category', `${map['keyword'] ?? ''}`);
        PageJumpTarget.putAttr(target, 'param', `${map['param'] ?? ''}`);
        return target;
      }
      target.page = action;
      return target;
    }
    return null;
  }

  private static parseString(sourceKey: string, value: string): PageJumpTarget | null {
    const target = new PageJumpTarget();
    target.sourceKey = sourceKey;
    const segments = value.split(':');
    const page = segments[0] ?? '';
    if (page === 'search') {
      target.page = 'search';
      PageJumpTarget.putAttr(target, 'text', segments.slice(1).join(':'));
      return target;
    }
    if (page === 'category') {
      target.page = 'category';
      const rest = segments.slice(1).join(':');
      if (rest.indexOf('@') >= 0) {
        const parts = rest.split('@');
        PageJumpTarget.putAttr(target, 'category', parts[0] ?? '');
        PageJumpTarget.putAttr(target, 'param', parts[1] ?? '');
      } else {
        PageJumpTarget.putAttr(target, 'category', rest);
      }
      return target;
    }
    target.page = page;
    return target;
  }

  private static putAttr(target: PageJumpTarget, key: string, value: string): void {
    target.attributes[key] = value;
  }

  private static attrsFrom(raw: Object | undefined): Record<string, string> {
    const out: Record<string, string> = {};
    if (!raw || typeof raw !== 'object') {
      return out;
    }
    const map = raw as Record<string, Object>;
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = map[k];
      if (v !== null && v !== undefined) {
        out[k] = `${v}`;
      }
    }
    return out;
  }

  /** 对齐 upstream PageJumpTarget.jump */
  static jump(target: PageJumpTarget | null): void {
    if (target === null || target.sourceKey.length === 0) {
      return;
    }
    if (target.page === 'search') {
      const text = target.attributes['text'] ?? target.attributes['keyword'] ?? '';
      router.pushUrl({
        url: 'pages/search/SearchResultPage',
        params: {
          sourceKey: target.sourceKey,
          sourceName: target.sourceKey,
          keyword: text,
          options: '[]'
        }
      });
      return;
    }
    if (target.page === 'category') {
      const item = new CategoryItem();
      item.label = target.attributes['category'] ?? '';
      item.param = target.attributes['param'] ?? '';
      item.partName = 'category';
      item.itemType = 'category';
      router.pushUrl({
        url: 'pages/categories/CategoryComicsPage',
        params: {
          sourceKey: target.sourceKey,
          categoryJson: JSON.stringify(item)
        }
      });
    }
  }
}
