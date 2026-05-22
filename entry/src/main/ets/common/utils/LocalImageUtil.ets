import { fileIo } from '@kit.CoreFileKit';

/** 本地漫画可读图片扩展名（与上游排序规则对齐） */
export const IMAGE_EXTENSIONS: string[] = [
  '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'
];

const COVER_NAMES: string[] = ['cover.jpg', 'cover.jpeg', 'cover.png', 'cover.webp'];

/**
 * 本地目录图片扫描与自然排序 — 阅读器与书架共用。
 */
export class LocalImageUtil {
  static isImageFile(name: string): boolean {
    const lower = name.toLowerCase();
    return IMAGE_EXTENSIONS.some((ext: string) => lower.endsWith(ext));
  }

  /** 自然排序：page2 < page10 */
  static naturalCompare(a: string, b: string): number {
    const re = /(\d+)|(\D+)/g;
    const at = a.toLowerCase().match(re) ?? [];
    const bt = b.toLowerCase().match(re) ?? [];
    const len = Math.min(at.length, bt.length);
    for (let i = 0; i < len; i++) {
      const an = Number(at[i]);
      const bn = Number(bt[i]);
      if (!isNaN(an) && !isNaN(bn)) {
        if (an !== bn) {
          return an - bn;
        }
      } else if (at[i] !== bt[i]) {
        return at[i] < bt[i] ? -1 : 1;
      }
    }
    return at.length - bt.length;
  }

  static listImageFiles(dirPath: string): string[] {
    try {
      const names = fileIo.listFileSync(dirPath)
        .filter((n: string) => !n.startsWith('.') && LocalImageUtil.isImageFile(n));
      names.sort((a: string, b: string) => LocalImageUtil.naturalCompare(a, b));
      return names.map((n: string) => `${dirPath}/${n}`);
    } catch (_e) {
      return [];
    }
  }

  /** 子目录若含图片则视为章节 */
  static listChapterSubdirs(comicDir: string): string[] {
    try {
      const entries = fileIo.listFileSync(comicDir);
      const chapters: string[] = [];
      for (const name of entries) {
        if (name.startsWith('.')) {
          continue;
        }
        const full = `${comicDir}/${name}`;
        try {
          const stat = fileIo.statSync(full);
          if (stat.isDirectory() && LocalImageUtil.listImageFiles(full).length > 0) {
            chapters.push(name);
          }
        } catch (_e) {
          // skip
        }
      }
      chapters.sort((a: string, b: string) => LocalImageUtil.naturalCompare(a, b));
      return chapters;
    } catch (_e) {
      return [];
    }
  }

  static resolveCoverPath(comicDir: string): string {
    for (const cover of COVER_NAMES) {
      const p = `${comicDir}/${cover}`;
      try {
        fileIo.statSync(p);
        return p;
      } catch (_e) {
        // try next
      }
    }
    const images = LocalImageUtil.listImageFiles(comicDir);
    if (images.length > 0) {
      return images[0];
    }
    const chapters = LocalImageUtil.listChapterSubdirs(comicDir);
    if (chapters.length > 0) {
      const first = LocalImageUtil.listImageFiles(`${comicDir}/${chapters[0]}`);
      if (first.length > 0) {
        return first[0];
      }
    }
    return `${comicDir}/cover.jpg`;
  }

  static countPages(comicDir: string): number {
    const root = LocalImageUtil.resolveComicRoot(comicDir);
    const flat = LocalImageUtil.listImageFiles(root);
    if (flat.length > 0) {
      return flat.length;
    }
    let total = 0;
    for (const ch of LocalImageUtil.listChapterSubdirs(root)) {
      total += LocalImageUtil.listImageFiles(`${root}/${ch}`).length;
    }
    return total;
  }

  /**
   * 解压后若根目录无图、仅含一个有效子目录，则使用该子目录作为漫画根（对齐上游 cbz 扁平化逻辑）。
   */
  static resolveComicRoot(comicDir: string): string {
    if (LocalImageUtil.listImageFiles(comicDir).length > 0) {
      return comicDir;
    }
    try {
      const entries = fileIo.listFileSync(comicDir).filter((n: string) => !n.startsWith('.'));
      const subdirs: string[] = [];
      for (const name of entries) {
        const full = `${comicDir}/${name}`;
        try {
          const stat = fileIo.statSync(full);
          if (stat.isDirectory()) {
            subdirs.push(name);
          }
        } catch (_e) {
          // skip
        }
      }
      if (subdirs.length === 1) {
        const inner = `${comicDir}/${subdirs[0]}`;
        if (LocalImageUtil.listImageFiles(inner).length > 0 ||
          LocalImageUtil.listChapterSubdirs(inner).length > 0) {
          return inner;
        }
      }
    } catch (_e) {
      // use original
    }
    return comicDir;
  }

  static resolveReadingDirectory(comicDir: string, chapterId?: string): string {
    const root = LocalImageUtil.resolveComicRoot(comicDir);
    if (chapterId && chapterId.length > 0) {
      return `${root}/${chapterId}`;
    }
    const flat = LocalImageUtil.listImageFiles(root);
    if (flat.length > 0) {
      return root;
    }
    const chapters = LocalImageUtil.listChapterSubdirs(root);
    if (chapters.length > 0) {
      return `${root}/${chapters[0]}`;
    }
    return root;
  }
}
