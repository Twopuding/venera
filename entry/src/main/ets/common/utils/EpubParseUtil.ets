import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { EpubChapter } from '../models/ComicModels';

/**
 * EPUB OPF 书脊解析（API 23 沙箱文件，轻量正则，无第三方 XML 库）。
 */
export class EpubParseUtil {
  private static textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });

  static isEpubBook(comicDir: string): boolean {
    return EpubParseUtil.findOpfPath(comicDir).length > 0;
  }

  static listSpineChapters(comicDir: string): EpubChapter[] {
    const opfPath = EpubParseUtil.findOpfPath(comicDir);
    if (opfPath.length === 0) {
      return [];
    }
    const opfText = EpubParseUtil.readTextFile(opfPath);
    if (opfText.length === 0) {
      return [];
    }
    const opfDir = opfPath.substring(0, opfPath.lastIndexOf('/'));
    const manifest = EpubParseUtil.parseManifest(opfText);
    const spineIds = EpubParseUtil.parseSpineIds(opfText);
    const chapters: EpubChapter[] = [];
    for (let i = 0; i < spineIds.length; i++) {
      const id = spineIds[i];
      const href = manifest.get(id) ?? '';
      if (href.length === 0) {
        continue;
      }
      const ch = new EpubChapter();
      ch.id = id;
      ch.title = `第 ${i + 1} 章`;
      ch.href = EpubParseUtil.resolveHref(opfDir, href);
      chapters.push(ch);
    }
    return chapters;
  }

  static chapterFileUrl(chapterPath: string): string {
    if (chapterPath.startsWith('file://')) {
      return chapterPath;
    }
    return `file://${chapterPath}`;
  }

  private static findOpfPath(comicDir: string): string {
    const container = `${comicDir}/META-INF/container.xml`;
    try {
      fileIo.statSync(container);
      const xml = EpubParseUtil.readTextFile(container);
      const m = xml.match(/full-path=["']([^"']+)["']/i);
      if (m && m[1]) {
        return EpubParseUtil.resolveHref(comicDir, m[1]);
      }
    } catch (_e) {
      // try walk
    }
    return EpubParseUtil.findOpfRecursive(comicDir, 0);
  }

  private static findOpfRecursive(dir: string, depth: number): string {
    if (depth > 4) {
      return '';
    }
    try {
      const names = fileIo.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const name = names[i];
        if (name.startsWith('.')) {
          continue;
        }
        const full = `${dir}/${name}`;
        const lower = name.toLowerCase();
        if (lower.endsWith('.opf')) {
          return full;
        }
        try {
          const stat = fileIo.statSync(full);
          if (stat.isDirectory()) {
            const found = EpubParseUtil.findOpfRecursive(full, depth + 1);
            if (found.length > 0) {
              return found;
            }
          }
        } catch (_e) {
          // skip
        }
      }
    } catch (_e) {
      return '';
    }
    return '';
  }

  private static parseManifest(opf: string): Map<string, string> {
    const map = new Map<string, string>();
    const re = /<item\b[^>]*\bid=["']([^"']+)["'][^>]*\bhref=["']([^"']+)["'][^>]*\/?>/gi;
    let m = re.exec(opf);
    while (m) {
      map.set(m[1], m[2]);
      m = re.exec(opf);
    }
    const re2 = /<item\b[^>]*\bhref=["']([^"']+)["'][^>]*\bid=["']([^"']+)["'][^>]*\/?>/gi;
    let m2 = re2.exec(opf);
    while (m2) {
      map.set(m2[2], m2[1]);
      m2 = re2.exec(opf);
    }
    return map;
  }

  private static parseSpineIds(opf: string): string[] {
    const ids: string[] = [];
    const re = /<itemref\b[^>]*\bidref=["']([^"']+)["'][^>]*\/?>/gi;
    let m = re.exec(opf);
    while (m) {
      ids.push(m[1]);
      m = re.exec(opf);
    }
    return ids;
  }

  private static resolveHref(baseDir: string, href: string): string {
    const parts = href.split('/');
    const stack = baseDir.split('/');
    for (let i = 0; i < parts.length; i++) {
      const seg = parts[i];
      if (seg.length === 0 || seg === '.') {
        continue;
      }
      if (seg === '..') {
        stack.pop();
      } else {
        stack.push(seg);
      }
    }
    return stack.join('/');
  }

  private static readTextFile(path: string): string {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      const bytes = new Uint8Array(buf);
      return EpubParseUtil.textDecoder.decodeWithStream(bytes);
    } catch (_e) {
      return '';
    }
  }
}
