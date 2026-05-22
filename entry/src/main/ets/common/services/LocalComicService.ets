import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LocalComicChapter, LocalComicItem } from '../models/ComicModels';
import { AppConstants } from '../constants/AppConstants';
import { LocalImageUtil } from '../utils/LocalImageUtil';
import { DocumentImportHelper } from '../utils/DocumentImportHelper';
import { ArchiveExtractUtil } from '../utils/ArchiveExtractUtil';

/**
 * Local comic library — port of upstream foundation/local.dart (simplified).
 * Supports directory scan, DocumentPicker import, chapter detection.
 */
export class LocalComicService {
  private static instance: LocalComicService;
  private comics: LocalComicItem[] = [];
  private rootPath: string = '';
  private context?: common.UIAbilityContext;
  private listeners: Array<() => void> = [];

  static getInstance(): LocalComicService {
    if (!LocalComicService.instance) {
      LocalComicService.instance = new LocalComicService();
    }
    return LocalComicService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.rootPath = `${context.filesDir}/${AppConstants.LOCAL_COMICS_DIR}`;
    try {
      fileIo.mkdirSync(this.rootPath);
    } catch (_e) {
      // directory may already exist
    }
    await this.scanLibrary();
  }

  getContext(): common.UIAbilityContext | undefined {
    return this.context;
  }

  getComics(): LocalComicItem[] {
    return this.comics;
  }

  getComicById(id: string): LocalComicItem | undefined {
    return this.comics.find((c: LocalComicItem) => c.id === id);
  }

  getRootPath(): string {
    return this.rootPath;
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  private notify(): void {
    this.listeners.forEach((l: () => void) => l());
  }

  async scanLibrary(): Promise<void> {
    this.comics = [];
    try {
      const entries = fileIo.listFileSync(this.rootPath);
      for (const name of entries) {
        if (name.startsWith('.')) {
          continue;
        }
        const fullPath = `${this.rootPath}/${name}`;
        try {
          const stat = fileIo.statSync(fullPath);
          if (stat.isDirectory()) {
            await this.tryExtractPendingArchive(fullPath);
            this.comics.push(this.buildComicItem(name, fullPath));
          }
        } catch (_e) {
          // skip invalid entry
        }
      }
      this.comics.sort((a: LocalComicItem, b: LocalComicItem) =>
        LocalImageUtil.naturalCompare(a.title, b.title));
    } catch (_e) {
      this.comics = [];
    }
    this.notify();
  }

  private buildComicItem(id: string, fullPath: string): LocalComicItem {
    const comicRoot = LocalImageUtil.resolveComicRoot(fullPath);
    const item = new LocalComicItem();
    item.id = id;
    item.title = id;
    item.directory = fullPath;
    item.coverPath = LocalImageUtil.resolveCoverPath(comicRoot);
    const chapterNames = LocalImageUtil.listChapterSubdirs(comicRoot);
    const flatImages = LocalImageUtil.listImageFiles(comicRoot);
    if (chapterNames.length > 0) {
      item.chapterCount = chapterNames.length;
      item.chapters = chapterNames.map((ch: string) => {
        const chDir = `${comicRoot}/${ch}`;
        const chapter = new LocalComicChapter();
        chapter.id = ch;
        chapter.title = ch;
        chapter.directory = chDir;
        chapter.pageCount = LocalImageUtil.listImageFiles(chDir).length;
        return chapter;
      });
      item.pageCount = item.chapters.reduce((sum: number, c: LocalComicChapter) => sum + c.pageCount, 0);
    } else {
      item.chapterCount = flatImages.length > 0 ? 1 : 0;
      item.pageCount = flatImages.length;
    }
    return item;
  }

  /**
   * 通过系统选择器导入漫画文件夹或压缩包（压缩包仅复制，解压待 P1）。
   */
  async importFromPicker(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    let imported = false;
    const folderUri = await DocumentImportHelper.pickComicFolder(this.context);
    if (folderUri) {
      imported = await this.copyUriIntoLibrary(folderUri, DocumentImportHelper.folderNameFromUri(folderUri));
    }
    if (!imported) {
      const archives = await DocumentImportHelper.pickArchiveFiles(this.context);
      for (const uri of archives) {
        const ok = await this.copyUriIntoLibrary(uri, DocumentImportHelper.archiveNameFromUri(uri), true);
        if (ok) {
          imported = true;
        }
      }
    }
    if (imported) {
      await this.scanLibrary();
    }
    return imported;
  }

  private async copyUriIntoLibrary(srcUri: string, destName: string, isFile: boolean = false): Promise<boolean> {
    const safeName = this.uniqueDestName(destName);
    try {
      if (isFile) {
        const ext = this.fileExtension(srcUri);
        if (ArchiveExtractUtil.is7zArchive(srcUri) || ext === '.7z' || ext === '.cb7') {
          console.warn('[LocalComicService] 7z/cb7 需原生解压模块，当前 API 23 仅支持 ZIP/CBZ');
          return false;
        }
        const destDir = `${this.rootPath}/${safeName}`;
        fileIo.mkdirSync(destDir, true);
        const archivePath = `${destDir}/__import${ext}`;
        await fileIo.copy(srcUri, archivePath);
        if (ArchiveExtractUtil.isZipArchive(archivePath)) {
          await ArchiveExtractUtil.extractZipToDir(archivePath, destDir);
          try {
            fileIo.unlinkSync(archivePath);
          } catch (_e) {
            // ignore
          }
        }
        const effectiveRoot = LocalImageUtil.resolveComicRoot(destDir);
        if (LocalImageUtil.listImageFiles(effectiveRoot).length === 0 &&
          LocalImageUtil.listChapterSubdirs(effectiveRoot).length === 0) {
          console.error('[LocalComicService] archive contains no readable images');
          return false;
        }
      } else {
        const destPath = `${this.rootPath}/${safeName}`;
        await fileIo.copyDir(srcUri, destPath);
      }
      return true;
    } catch (e) {
      console.error(`[LocalComicService] import copy failed: ${e}`);
      return false;
    }
  }

  /** 扫描时若目录内仅有未解压的 ZIP/CBZ，自动解压（兼容旧版导入）。 */
  private async tryExtractPendingArchive(comicDir: string): Promise<void> {
    const images = LocalImageUtil.listImageFiles(comicDir);
    const chapters = LocalImageUtil.listChapterSubdirs(comicDir);
    if (images.length > 0 || chapters.length > 0) {
      return;
    }
    try {
      const names = fileIo.listFileSync(comicDir);
      const archives = names.filter((n: string) =>
        ArchiveExtractUtil.isZipArchive(n) && !n.startsWith('.'));
      if (archives.length !== 1) {
        return;
      }
      const archivePath = `${comicDir}/${archives[0]}`;
      await ArchiveExtractUtil.extractZipToDir(archivePath, comicDir);
      try {
        fileIo.unlinkSync(archivePath);
      } catch (_e) {
        // ignore
      }
    } catch (e) {
      console.warn(`[LocalComicService] pending extract skipped: ${e}`);
    }
  }

  private fileExtension(uri: string): string {
    const lower = decodeURIComponent(uri).toLowerCase();
    for (const ext of ['.cbz', '.zip', '.7z', '.cb7']) {
      if (lower.endsWith(ext)) {
        return ext;
      }
    }
    return '.zip';
  }

  private uniqueDestName(base: string): string {
    let name = base;
    let i = 1;
    while (this.comics.some((c: LocalComicItem) => c.id === name)) {
      name = `${base}_${i}`;
      i++;
    }
    try {
      fileIo.statSync(`${this.rootPath}/${name}`);
      name = `${base}_${Date.now()}`;
    } catch (_e) {
      // not exists — ok
    }
    return name;
  }

  async importDirectory(sourceUri: string): Promise<boolean> {
    const name = DocumentImportHelper.folderNameFromUri(sourceUri);
    const ok = await this.copyUriIntoLibrary(sourceUri, name);
    if (ok) {
      await this.scanLibrary();
    }
    return ok;
  }
}
