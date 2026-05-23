import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LocalComicChapter, LocalComicItem } from '../models/ComicModels';
import { AppConstants } from '../constants/AppConstants';
import { LocalImageUtil } from '../utils/LocalImageUtil';
import { DocumentImportHelper } from '../utils/DocumentImportHelper';
import { ArchiveExtractUtil } from '../utils/ArchiveExtractUtil';
import { EpubParseUtil } from '../utils/EpubParseUtil';
import { EpubChapter } from '../models/ComicModels';
import { FileIoUtil } from '../utils/FileIoUtil';
import { HistoryService } from './HistoryService';

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
    setTimeout(() => {
      this.scanLibrary().then(() => this.notify()).catch((e: Error) => {
        console.warn(`[LocalComicService] scanLibrary failed: ${e}`);
      });
    }, 0);
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
    const pdfPath = LocalComicService.findPdfInDir(fullPath);
    if (pdfPath.length > 0) {
      const item = new LocalComicItem();
      item.id = id;
      item.title = id;
      item.directory = fullPath;
      item.mediaType = 'pdf';
      item.pdfPath = pdfPath;
      item.coverPath = '';
      item.chapterCount = 1;
      item.pageCount = 0;
      return item;
    }
    const comicRoot = LocalImageUtil.resolveComicRoot(fullPath);
    const item = new LocalComicItem();
    item.id = id;
    item.title = id;
    item.directory = fullPath;
    item.mediaType = 'images';
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
    if (item.pageCount === 0 && EpubParseUtil.isEpubBook(comicRoot)) {
      const epubChapters = EpubParseUtil.listSpineChapters(comicRoot);
      if (epubChapters.length > 0) {
        item.mediaType = 'epub';
        item.chapterCount = epubChapters.length;
        item.chapters = epubChapters.map((ch: EpubChapter) => {
          const chapter = new LocalComicChapter();
          chapter.id = ch.id;
          chapter.title = ch.title;
          chapter.directory = ch.href;
          chapter.pageCount = 1;
          return chapter;
        });
        item.pageCount = epubChapters.length;
        item.coverPath = '';
      }
    }
    const hist = HistoryService.getInstance().find(id, 'local');
    if (hist) {
      item.lastReadChapterId = hist.chapterId;
      item.lastReadPage = hist.pageIndex;
    }
    return item;
  }

  /** 从书架移除本地漫画目录 */
  async removeComic(id: string): Promise<boolean> {
    const comic = this.getComicById(id);
    if (!comic || comic.directory.length === 0) {
      return false;
    }
    try {
      FileIoUtil.deleteRecursive(comic.directory);
    } catch (e) {
      console.error(`[LocalComicService] remove failed: ${e}`);
      return false;
    }
    await this.scanLibrary();
    return true;
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
    if (!imported) {
      const pdfs = await DocumentImportHelper.pickPdfFiles(this.context);
      for (const uri of pdfs) {
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
        const destDir = `${this.rootPath}/${safeName}`;
        fileIo.mkdirSync(destDir, true);
        const archivePath = `${destDir}/__import${ext}`;
        await fileIo.copy(srcUri, archivePath);
        if (ext === '.pdf') {
          const pdfDest = `${destDir}/book.pdf`;
          try {
            fileIo.renameSync(archivePath, pdfDest);
          } catch (_e) {
            await fileIo.copy(srcUri, pdfDest);
          }
          return true;
        }
        if (ArchiveExtractUtil.isZipArchive(archivePath) || ArchiveExtractUtil.is7zArchive(archivePath)) {
          await ArchiveExtractUtil.extractArchiveToDir(archivePath, destDir);
          try {
            fileIo.unlinkSync(archivePath);
          } catch (_e) {
            // ignore
          }
        }
        const effectiveRoot = LocalImageUtil.resolveComicRoot(destDir);
        if (LocalImageUtil.listImageFiles(effectiveRoot).length === 0 &&
          LocalImageUtil.listChapterSubdirs(effectiveRoot).length === 0 &&
          LocalComicService.findPdfInDir(destDir).length === 0 &&
          !EpubParseUtil.isEpubBook(effectiveRoot)) {
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
        (ArchiveExtractUtil.isZipArchive(n) || ArchiveExtractUtil.is7zArchive(n)) && !n.startsWith('.'));
      if (archives.length !== 1) {
        return;
      }
      const archivePath = `${comicDir}/${archives[0]}`;
      await ArchiveExtractUtil.extractArchiveToDir(archivePath, comicDir);
      try {
        fileIo.unlinkSync(archivePath);
      } catch (_e) {
        // ignore
      }
    } catch (e) {
      console.warn(`[LocalComicService] pending extract skipped: ${e}`);
    }
  }

  private static findPdfInDir(dir: string): string {
    try {
      const names = fileIo.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const n = names[i];
        if (n.toLowerCase().endsWith('.pdf')) {
          return `${dir}/${n}`;
        }
      }
    } catch (_e) {
      // empty
    }
    return '';
  }

  private fileExtension(uri: string): string {
    const lower = decodeURIComponent(uri).toLowerCase();
    for (const ext of ['.cbz', '.zip', '.7z', '.cb7', '.epub', '.pdf']) {
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
