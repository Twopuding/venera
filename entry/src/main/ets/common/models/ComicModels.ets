/** Comic domain models ported from upstream lib/foundation/comic_source/models.dart */

/** loadInfo 按命名空间分组的标签（对齐 upstream ComicDetails.tags） */
export class ComicTagGroup {
  namespace: string = '';
  tags: string[] = [];
}

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
  /** 上游 comic.loadInfo 的 updateTime 字段 */
  updateTime?: string;
  /** 详情页扩展字段（对齐 ComicDetails） */
  url?: string;
  isLiked?: boolean;
  likesCount?: number;
  commentCount?: number;
  uploader?: string;
  uploadTime?: string;
  isFavorite?: boolean;
  tagGroups?: ComicTagGroup[];
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
  /** 脚本要求的最低应用版本（对齐上游 minAppVersion） */
  minAppVersion: string = '';
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

/** 搜索页可选图源（对齐上游 findSearchSources） */
export class SearchPageSourceItem {
  key: string = '';
  name: string = '';
}

/** 搜索选项定义（对齐上游 search.optionList） */
export class SearchOptionDef {
  label: string = '';
  type: string = 'select';
  options: SourceSettingOption[] = [];
  defaultValue: string = '';
}

/** 搜索框智能建议上下文（linkHandler / idMatcher） */
export class SearchSuggestionContext {
  linkSourceKey: string = '';
  linkComicId: string = '';
  idMatchSources: SearchPageSourceItem[] = [];
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
  /** favorites.loadNext 游标 */
  next: string = '';
  error: string = '';
}

/** 图源 favorites 元数据 */
export class NetworkFavoriteMeta {
  sourceKey: string = '';
  favoriteKey: string = '';
  title: string = '';
  multiFolder: boolean = false;
  hasLoadComics: boolean = false;
  hasLoadNext: boolean = false;
  hasAddOrDel: boolean = false;
}

/** favorites.loadFolders 结果 */
export class FavoriteFoldersResult {
  folders: Record<string, string> = {};
  /** 漫画已加入的网络收藏夹 id 列表 */
  addedFolderIds: string[] = [];
  error: string = '';
}

/** 漫画源 explore.load 分区（如包子「热门推荐」） */
export class ExploreSection {
  title: string = '';
  comics: Comic[] = [];
  /** 对齐 ExplorePagePart.viewMore */
  viewMoreJson: string = '';
}

/** mixed 探索页块：分区标题行或纯漫画网格 */
export class ExploreMixedBlock {
  kind: string = 'section';
  title: string = '';
  comics: Comic[] = [];
  viewMoreJson: string = '';
}

/** explore 页元数据（标题 → 图源） */
export class ExplorePageMeta {
  title: string = '';
  sourceKey: string = '';
}

/** 分类 Tab 页元数据 — 对齐 upstream categoryData.key */
export class CategoryPageMeta {
  key: string = '';
  title: string = '';
  sourceKey: string = '';
}

/** 按 explore_pages 标题加载单页探索内容 */
export class ExplorePageLoadResult {
  sourceKey: string = '';
  exploreTitle: string = '';
  /** multiPartPage / singlePageWithMultiPart */
  sections: ExploreSection[] = [];
  /** multiPageComicList */
  comics: Comic[] = [];
  /** mixed */
  mixedBlocks: ExploreMixedBlock[] = [];
  maxPage: number = 1;
  page: number = 1;
  /** loadNext 游标 */
  nextCursor: string = '';
  error: string = '';
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
  /** 当前章节总页数（1-based 展示用）— 对齐 upstream History.maxPage */
  maxPage?: number;
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
