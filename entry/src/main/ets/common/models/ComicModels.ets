/** Comic domain models ported from upstream lib/foundation/comic_source/models.dart */

export class Comic {
  title: string = '';
  cover: string = '';
  id: string = '';
  subtitle?: string;
  tags?: string[];
  description: string = '';
  sourceKey: string = '';
  maxPage?: number;
  language?: string;
  favoriteId?: string;
  stars?: number;
}

export class ComicChapter {
  id: string = '';
  title: string = '';
  subTitle?: string;
  cover?: string;
  pageCount?: number;
  isDownloaded: boolean = false;
}

export class ComicSourceInfo {
  key: string = '';
  name: string = '';
  version: string = '';
  description: string = '';
  enabled: boolean = true;
}

export class LocalComicChapter {
  id: string = '';
  title: string = '';
  directory: string = '';
  pageCount: number = 0;
}

export class LocalComicItem {
  id: string = '';
  title: string = '';
  coverPath: string = '';
  directory: string = '';
  chapterCount: number = 0;
  chapters: LocalComicChapter[] = [];
  pageCount: number = 0;
  lastReadChapterId?: string;
  lastReadPage: number = 0;
}

export class ReadingHistoryEntry {
  comicId: string = '';
  sourceKey: string = 'local';
  title: string = '';
  coverPath: string = '';
  directory: string = '';
  chapterId: string = '';
  pageIndex: number = 0;
  updatedAt: number = 0;
}

export class DownloadTask {
  id: string = '';
  comicTitle: string = '';
  chapterTitle: string = '';
  sourceKey: string = '';
  resourceUrl: string = '';
  destPath: string = '';
  progress: number = 0;
  status: 'pending' | 'downloading' | 'completed' | 'failed' = 'pending';
  totalBytes: number = 0;
  downloadedBytes: number = 0;
}

export class ReaderState {
  comicId: string = '';
  sourceKey: string = '';
  chapterId: string = '';
  currentPage: number = 0;
  pageUrls: string[] = [];
  readingMode: 'vertical' | 'horizontal' = 'vertical';
}
