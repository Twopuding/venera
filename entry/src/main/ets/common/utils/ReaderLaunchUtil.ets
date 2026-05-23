import { router } from '@kit.ArkUI';
import { LocalComicService } from '../services/LocalComicService';
import { LocalComicChapter, LocalComicItem, ReadingHistoryEntry } from '../models/ComicModels';

/** 统一打开本地/在线阅读器 */
export class ReaderLaunchUtil {
  static openLocalComic(item: LocalComicItem, chapterId?: string, pageIndex?: number): void {
    if (item.mediaType === 'pdf' && item.pdfPath.length > 0) {
      router.pushUrl({
        url: 'pages/reader/PdfReaderPage',
        params: { title: item.title, pdfPath: item.pdfPath, comicId: item.id }
      });
      return;
    }
    if (item.mediaType === 'epub') {
      let chapterPath = '';
      if (chapterId && chapterId.length > 0) {
        const ch = item.chapters.find((c: LocalComicChapter) => c.id === chapterId);
        chapterPath = ch?.directory ?? '';
      }
      if (chapterPath.length === 0 && item.chapters.length > 0) {
        const idx = pageIndex !== undefined && pageIndex >= 0 && pageIndex < item.chapters.length ?
          pageIndex : 0;
        chapterPath = item.chapters[idx].directory;
      }
      router.pushUrl({
        url: 'pages/reader/EpubReaderPage',
        params: { title: item.title, chapterPath: chapterPath, comicId: item.id }
      });
      return;
    }
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: item.id,
        sourceKey: 'local',
        title: item.title,
        directory: item.directory,
        coverPath: item.coverPath,
        chapterId: chapterId ?? '',
        pageIndex: String(pageIndex ?? item.lastReadPage ?? 0)
      }
    });
  }

  static openFromHistory(entry: ReadingHistoryEntry): void {
    if (entry.sourceKey === 'local') {
      const comic = LocalComicService.getInstance().getComicById(entry.comicId);
      if (comic) {
        ReaderLaunchUtil.openLocalComic(comic, entry.chapterId, entry.pageIndex);
      }
      return;
    }
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: entry.comicId,
        sourceKey: entry.sourceKey,
        title: entry.title,
        chapterId: entry.chapterId,
        pageIndex: String(entry.pageIndex)
      }
    });
  }
}
