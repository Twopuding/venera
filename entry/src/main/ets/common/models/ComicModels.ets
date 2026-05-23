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

/** 漫画详情评论（对齐 init.js Comment） */
export class ComicComment {
  id: string = '';
  userName: string = '';
  avatar: string = '';
  content: string = '';
  time: string = '';
}

/** comic.loadInfo 解析结果 */
export class ComicInfoResult {
  comic: Comic = new Comic();
  chapters: ComicChapter[] = [];
  comments: ComicComment[] = [];
  recommend: Comic[] = [];
}

export class ComicSourceInfo {
  key: string = '';
  name: string = '';
  version: string = '';
  description: string = '';
  url: string = '';
  /** index.json 中的 fileName，如 baozi.js */
  scriptFile: string = '';
  enabled: boolean = true;
}

/** 已装入 QuickJS 的漫画源（对齐上游 ComicSource） */
export class InstalledComicSource {
  key: string = '';
  name: string = '';
  version: string = '';
  url: string = '';
  filePath: string = '';
  /** index 中有更新版本时填入 */
  pendingVersion: string = '';
}

/** 漫画源 account 配置摘要 */
export class SourceAccountConfig {
  loginWebsite: string = '';
  registerWebsite: string = '';
  hasPasswordLogin: boolean = false;
  hasCookieLogin: boolean = false;
  cookieFields: string[] = [];
}

export class SourceSettingOption {
  value: string = '';
  text: string = '';
}

/** settings 项定义（select / switch / input / callback） */
export class SourceSettingDef {
  key: string = '';
  type: string = '';
  title: string = '';
  defaultValue: string | boolean = '';
  options: SourceSettingOption[] = [];
  validator: string = '';
  buttonText: string = '';
}

/** 漫画源排行榜元数据（category.enableRankingPage + categoryComics.ranking） */
export class RankingPageInfo {
  sourceKey: string = '';
  categoryTitle: string = '';
  options: string[] = [];
}

/** 聚合搜索单源预览行 */
export class AggregatedSearchRow {
  sourceKey: string = '';
  sourceName: string = '';
  comics: Comic[] = [];
  loading: boolean = false;
  error: string = '';
}

/** 分类页条目（对齐上游 category.parts） */
export class CategoryItem {
  label: string = '';
  param: string = '';
  partName: string = '';
  itemType: string = 'category';
}

/** categoryComics.load / search.load 分页结果 */
export class CategoryComicsResult {
  comics: Comic[] = [];
  maxPage: number = 1;
}

/** 漫画源 explore.load 分区（如包子「热门推荐」） */
export class ExploreSection {
  title: string = '';
  comics: Comic[] = [];
}

/** 按 explore_pages 标题加载单页探索内容 */
export class ExplorePageLoadResult {
  sourceKey: string = '';
  exploreTitle: string = '';
  sections: ExploreSection[] = [];
  comics: Comic[] = [];
  maxPage: number = 1;
  page: number = 1;
}

/** EPUB 书脊章节 */
export class EpubChapter {
  id: string = '';
  title: string = '';
  /** 相对漫画根目录的 XHTML 路径 */
  href: string = '';
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
  /** images：图片/CBZ；pdf：单文件 PDF；epub：文字/HTML 书脊 */
  mediaType: string = 'images';
  pdfPath: string = '';
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
