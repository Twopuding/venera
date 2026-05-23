import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  Comic,
  ComicChapter,
  ComicComment,
  ComicTagGroup,
  DownloadTask,
  ReadingHistoryEntry
} from '../../common/models/ComicModels';
import { LocalFavoritesService } from '../../common/services/LocalFavoritesService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { HistoryService } from '../../common/services/HistoryService';
import { DownloadService } from '../../common/services/DownloadService';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { ComicImageResolver } from '../../common/utils/ComicImageResolver';
import { SysTheme } from '../../common/theme/SysTheme';
import { TagTranslationService } from '../../common/services/TagTranslationService';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { AppDataService } from '../../common/services/AppDataService';

/**
 * 漫画详情 — 对齐 upstream lib/pages/comic_details_page/comic_page.dart
 */
@Entry
@Component
struct ComicDetailPage {
  @State comic: Comic = new Comic();
  @State isFavorite: boolean = false;
  @State chapters: ComicChapter[] = [];
  @State comments: ComicComment[] = [];
  @State recommend: Comic[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State chapterHint: string = '';
  @State downloadingChapterId: string = '';
  @State coverSrc: string = '';
  @State displayTitle: string = '';
  @State displayDescription: string = '';
  @State displayTags: string[] = [];
  @State sourceName: string = '';
  @State descExpanded: boolean = false;
  @State chapterReversed: boolean = false;
  @State showAllChapters: boolean = false;
  @State showMoreMenu: boolean = false;
  @State showScrollTop: boolean = false;
  @State supportsLike: boolean = false;
  @State isLiking: boolean = false;
  @State historyLabel: string = '';
  private history?: ReadingHistoryEntry;
  private scroller: Scroller = new Scroller();
  private static readonly CHAPTER_PREVIEW = 24;

  onPageShow(): void {
    LocalFavoritesService.getInstance()
      .isExistAsync(this.comic.id, this.comic.sourceKey)
      .then((v: boolean) => {
        this.isFavorite = v;
      });
  }

  aboutToAppear(): void {
    this.chapterReversed = AppDataService.getInstance().settings.reverseChapterOrder;
    const params = router.getParams() as Record<string, string>;
    if (params['comicJson']) {
      this.comic = JSON.parse(params['comicJson']) as Comic;
      this.applyDisplayFields();
      const src = ComicSourceService.getInstance().getSourceByKey(this.comic.sourceKey);
      this.sourceName = src?.name ?? this.comic.sourceKey;
      this.history = HistoryService.getInstance().find(this.comic.id, this.comic.sourceKey);
      this.updateHistoryLabel();
      LocalFavoritesService.getInstance()
        .isExistAsync(this.comic.id, this.comic.sourceKey)
        .then((v: boolean) => {
          this.isFavorite = v;
        });
      this.resolveCover();
      this.loadComicDetails();
    } else {
      this.loading = false;
      this.error = '无效的漫画参数';
    }
  }

  private applyDisplayFields(): void {
    this.displayTitle = TagTranslationService.translateTagLine(this.comic.title);
    this.displayDescription = TagTranslationService.translateTagLine(this.comic.description);
    this.displayTags = [];
    if (this.comic.tagGroups && this.comic.tagGroups.length > 0) {
      return;
    }
    if (this.comic.tags) {
      for (let i = 0; i < this.comic.tags.length; i++) {
        this.displayTags.push(TagTranslationService.translateTagLine(this.comic.tags[i]));
      }
    }
  }

  private mergeComicInfo(from: Comic): void {
    if (from.title.length > 0) {
      this.comic.title = from.title;
    }
    if (from.cover.length > 0) {
      this.comic.cover = from.cover;
    }
    if (from.description.length > 0) {
      this.comic.description = from.description;
    }
    if (from.tags && from.tags.length > 0) {
      this.comic.tags = from.tags;
    }
    if (from.tagGroups && from.tagGroups.length > 0) {
      this.comic.tagGroups = from.tagGroups;
    }
    if (from.subtitle) {
      this.comic.subtitle = from.subtitle;
    }
    if (from.stars !== undefined) {
      this.comic.stars = from.stars;
    }
    if (from.updateTime) {
      this.comic.updateTime = from.updateTime;
    }
    if (from.uploadTime) {
      this.comic.uploadTime = from.uploadTime;
    }
    if (from.uploader) {
      this.comic.uploader = from.uploader;
    }
    if (from.url) {
      this.comic.url = from.url;
    }
    if (from.maxPage !== undefined) {
      this.comic.maxPage = from.maxPage;
    }
    if (from.isLiked !== undefined) {
      this.comic.isLiked = from.isLiked;
    }
    if (from.likesCount !== undefined) {
      this.comic.likesCount = from.likesCount;
    }
    if (from.commentCount !== undefined) {
      this.comic.commentCount = from.commentCount;
    }
    if (from.isFavorite !== undefined) {
      this.comic.isFavorite = from.isFavorite;
      if (from.isFavorite) {
        this.isFavorite = true;
      }
    }
    this.applyDisplayFields();
    this.resolveCover();
  }

  private updateHistoryLabel(): void {
    if (!this.history) {
      this.historyLabel = '';
      return;
    }
    const page = this.history.pageIndex + 1;
    let epName = this.history.chapterId.length > 0 ? this.history.chapterId : `E${page}`;
    for (let i = 0; i < this.chapters.length; i++) {
      if (this.chapters[i].id === this.history!.chapterId) {
        epName = this.chapters[i].title;
        break;
      }
    }
    this.historyLabel = `上次阅读：${epName} · 第 ${page} 页`;
  }

  private hasContinueHistory(): boolean {
    return this.history !== undefined &&
      (this.history.pageIndex > 0 || this.history.chapterId.length > 0);
  }

  private async resolveCover(): Promise<void> {
    if (this.comic.cover.length === 0) {
      this.coverSrc = '';
      return;
    }
    this.coverSrc = ImageCacheUtil.resolveSync(this.comic.cover);
    if (ImageCacheUtil.isRemoteUrl(this.comic.cover) && this.coverSrc === this.comic.cover) {
      this.coverSrc = await ImageCacheUtil.ensureCached(this.comic.cover);
    }
  }

  private async loadComicDetails(): Promise<void> {
    if (this.comic.sourceKey.length === 0 || this.comic.id.length === 0) {
      this.loading = false;
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      await ComicSourceService.getInstance().ensureSourceReady(this.comic.sourceKey);
      this.supportsLike = await JsEngineBridge.getInstance()
        .invokeComicSupportsLike(this.comic.sourceKey);
      const info = await JsEngineBridge.getInstance()
        .invokeComicInfo(this.comic.sourceKey, this.comic.id);
      this.mergeComicInfo(info.comic);
      this.chapters = info.chapters;
      this.comments = info.comments;
      this.recommend = info.recommend;
      this.history = HistoryService.getInstance().find(this.comic.id, this.comic.sourceKey);
      this.updateHistoryLabel();
      const status = JsEngineBridge.getInstance().getStatus();
      if (this.chapters.length === 0) {
        this.chapterHint = status.runtimeReady ?
          '章节列表为空，请检查漫画源或登录状态' : status.runtimeNote;
      }
    } catch (e) {
      this.error = `${e}`;
    }
    this.loading = false;
  }

  private displayChapters(): ComicChapter[] {
    const list = [...this.chapters];
    if (this.chapterReversed) {
      list.reverse();
    }
    if (!this.showAllChapters && list.length > ComicDetailPage.CHAPTER_PREVIEW) {
      return list.slice(0, ComicDetailPage.CHAPTER_PREVIEW);
    }
    return list;
  }

  private formatTime(raw: string): string {
    const num = Number(raw);
    if (!isNaN(num) && num > 0) {
      const ms = num > 1000000000000 ? num : num * 1000;
      return new Date(ms).toISOString().replace('T', ' ').substring(0, 19);
    }
    if (raw.indexOf('T') >= 0) {
      try {
        return new Date(raw).toISOString().replace('T', ' ').substring(0, 19);
      } catch (_e) {
        return raw;
      }
    }
    return raw;
  }

  private openReader(chapter: ComicChapter, pageIndex: number = 0): void {
    let chapterIndex = 1;
    for (let i = 0; i < this.chapters.length; i++) {
      if (this.chapters[i].id === chapter.id) {
        chapterIndex = i + 1;
        break;
      }
    }
    const tagsJson = this.comic.tags && this.comic.tags.length > 0 ?
      JSON.stringify(this.comic.tags) : '[]';
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: this.comic.id,
        sourceKey: this.comic.sourceKey,
        title: `${this.comic.title} · ${chapter.title}`,
        chapterId: chapter.id,
        coverPath: this.comic.cover,
        chapterIndex: `${chapterIndex}`,
        pageIndex: `${pageIndex}`,
        epName: chapter.title,
        author: this.comic.subtitle ?? '',
        subtitle: this.comic.subtitle ?? '',
        tagsJson: tagsJson
      }
    });
  }

  private continueRead(): void {
    if (!this.history || this.chapters.length === 0) {
      return;
    }
    let chapter = this.chapters[0];
    if (this.history.chapterId.length > 0) {
      const found = this.chapters.find((c: ComicChapter) => c.id === this.history!.chapterId);
      if (found) {
        chapter = found;
      }
    }
    this.openReader(chapter, this.history.pageIndex);
  }

  private startRead(): void {
    if (this.chapters.length > 0) {
      this.openReader(this.chapters[0], 0);
    }
  }

  private openRecommendComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  private openFavoritePanel(): void {
    router.pushUrl({
      url: 'pages/comic/ComicFavoritePanelPage',
      params: { comicJson: JSON.stringify(this.comic) }
    });
  }

  private openCommentsPage(): void {
    router.pushUrl({
      url: 'pages/comic/ComicCommentsPage',
      params: {
        title: '评论',
        commentsJson: JSON.stringify(this.comments)
      }
    });
  }

  private searchTag(namespace: string, tag: string): void {
    const keyword = namespace.length > 0 ? `${namespace}:${tag}` : tag;
    router.pushUrl({
      url: 'pages/search/SearchPage',
      params: {
        keyword: keyword,
        sourceKey: this.comic.sourceKey,
        sourceName: this.sourceName
      }
    });
  }

  private async copyText(text: string, hint: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: hint, duration: 1500 });
    } catch (e) {
      console.warn(`[ComicDetailPage] copy: ${e}`);
    }
  }

  private shareComic(): void {
    let text = this.comic.title;
    if (this.comic.url && this.comic.url.length > 0) {
      text += `\n${this.comic.url}`;
    }
    this.copyText(text, '已复制分享内容');
  }

  private openInBrowser(): void {
    if (!this.comic.url || this.comic.url.length === 0) {
      return;
    }
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.openLink(this.comic.url, { appLinkingOnly: false }).catch((e: Error) => {
        console.error(`[ComicDetailPage] openLink: ${e}`);
      });
    } catch (e) {
      console.error(`[ComicDetailPage] openInBrowser: ${e}`);
    }
  }

  private async toggleLike(): Promise<void> {
    if (!this.supportsLike || this.isLiking || this.comic.isLiked === undefined) {
      return;
    }
    this.isLiking = true;
    const nextLiking = !(this.comic.isLiked ?? false);
    const err = await JsEngineBridge.getInstance()
      .invokeComicLike(this.comic.sourceKey, this.comic.id, nextLiking);
    this.isLiking = false;
    if (err.length > 0) {
      promptAction.showToast({ message: err, duration: 2500 });
      return;
    }
    this.comic.isLiked = nextLiking;
    if (this.comic.likesCount !== undefined) {
      const delta = nextLiking ? 1 : -1;
      this.comic.likesCount = Math.max(0, (this.comic.likesCount ?? 0) + delta);
    }
  }

  private async downloadChapter(chapter: ComicChapter): Promise<void> {
    if (this.downloadingChapterId.length > 0) {
      return;
    }
    this.downloadingChapterId = chapter.id;
    const entries = await JsEngineBridge.getInstance()
      .invokeComicPageEntries(this.comic.sourceKey, this.comic.id, chapter.id);
    if (entries.length === 0) {
      this.downloadingChapterId = '';
      return;
    }
    const pages = await ComicImageResolver.resolveAll(entries);
    const baseId = `${this.comic.sourceKey}_${this.comic.id}_${chapter.id}`;
    for (let i = 0; i < pages.length; i++) {
      const path = pages[i];
      if (path.length === 0) {
        continue;
      }
      const task = new DownloadTask();
      task.id = `${baseId}_${i}`;
      task.comicTitle = this.comic.title;
      task.chapterTitle = `${chapter.title} #${i + 1}`;
      task.sourceKey = this.comic.sourceKey;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        task.resourceUrl = path;
      } else {
        task.resourceUrl = `file://${path}`;
      }
      task.status = 'pending';
      await DownloadService.getInstance().enqueue(task);
    }
    this.downloadingChapterId = '';
    router.pushUrl({ url: 'pages/download/DownloadPage' });
  }

  @Builder
  headerTrailing() {
    Row() {
      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize(20)
        .fontColor([SysTheme.FONT_PRIMARY])
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showMoreMenu = true;
    })
  }

  build() {
    Stack() {
      Column() {
        SecondaryPageHeader({
          title: this.displayTitle.length > 0 ? this.displayTitle : this.comic.title,
          trailing: () => {
            this.headerTrailing();
          }
        })

        if (this.loading) {
          LoadingProgress().width(48).height(48).margin(24)
        } else if (this.error.length > 0) {
          Column() {
            Text(this.error)
              .fontSize(14)
              .fontColor('#FFE53935')
              .margin({ bottom: 16 })
            Button('重试')
              .onClick(() => this.loadComicDetails())
          }
          .padding(24)
          .layoutWeight(1)
        } else {
          Scroll(this.scroller) {
            Column() {
              this.buildTitleRow()
              this.buildActionBar()
              if (this.historyLabel.length > 0) {
                this.buildHistoryChip()
              }
              this.buildDescription()
              this.buildInfoSection()
              this.buildChapters()
              this.buildCommentsPreview()
              this.buildRecommend()
            }
            .width('100%')
            .padding({ bottom: 80 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .onScroll(() => {
            const off = this.scroller.currentOffset().yOffset;
            this.showScrollTop = off > 120;
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding(SafeAreaInsets.pagePadding())
      .backgroundColor(SysTheme.BACKGROUND_PRIMARY)

      if (this.showScrollTop) {
        Row() {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(22)
            .fontColor([SysTheme.FONT_PRIMARY])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
        .justifyContent(FlexAlign.Center)
        .position({ right: 20, bottom: 24 })
        .onClick(() => {
          this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 200 } });
        })
      }

      if (this.showMoreMenu) {
        this.buildMoreMenuOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildTitleRow() {
    Row({ space: 16 }) {
      Image(this.coverSrc.length > 0 ? this.coverSrc : this.comic.cover)
        .width(104)
        .height(144)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      Column() {
        Text(this.displayTitle.length > 0 ? this.displayTitle : this.comic.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(SysTheme.FONT_PRIMARY)
          .maxLines(3)
        if (this.comic.subtitle && this.comic.subtitle.length > 0) {
          Text(this.comic.subtitle)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .margin({ top: 4 })
            .maxLines(2)
        }
        Text(this.sourceName)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 8 })
  }

  @Builder
  buildActionBar() {
    Scroll() {
      Row({ space: 8 }) {
        if (this.hasContinueHistory()) {
          this.actionChip($r('sys.symbol.book'), '继续', () => this.continueRead())
        }
        this.actionChip($r('sys.symbol.arrow_right'), '阅读', () => this.startRead())
        this.actionChip(
          $r('sys.symbol.heart'),
          '收藏',
          () => this.openFavoritePanel()
        )
        if (this.supportsLike && this.comic.isLiked !== undefined) {
          this.actionChip(
            this.comic.isLiked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
            this.comic.likesCount !== undefined ? `${this.comic.likesCount}` : '点赞',
            () => this.toggleLike()
          )
        }
        if (this.comments.length > 0 || (this.comic.commentCount ?? 0) > 0) {
          this.actionChip(
            $r('sys.symbol.line_3_horizontal'),
            `${this.comic.commentCount ?? this.comments.length}`,
            () => this.openCommentsPage()
          )
        }
        this.actionChip($r('sys.symbol.link'), '分享', () => this.shareComic())
      }
      .padding({ left: 12, right: 12 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .margin({ top: 12, bottom: 8 })
  }

  @Builder
  actionChip(icon: Resource, label: string, onTap: () => void) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([SysTheme.FONT_PRIMARY])
      Text(label)
        .fontSize(13)
        .fontColor(SysTheme.FONT_PRIMARY)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .borderRadius(18)
    .border({ width: 1, color: SysTheme.BACKGROUND_SECONDARY })
    .onClick(onTap)
  }

  @Builder
  buildHistoryChip() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(16)
        .fontColor([SysTheme.EMPHASIZE])
      Text(this.historyLabel)
        .fontSize(13)
        .fontColor(SysTheme.FONT_PRIMARY)
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
    .borderRadius(20)
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  buildDescription() {
    if (this.comic.description.trim().length === 0) {
      Blank()
    } else {
      Column() {
        Text($r('app.string.description'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })
        Text(this.displayDescription.length > 0 ? this.displayDescription : this.comic.description)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16 })
          .maxLines(this.descExpanded ? 999 : 6)
        if (!this.descExpanded) {
          Text('展开')
            .fontSize(13)
            .fontColor(SysTheme.EMPHASIZE)
            .padding({ left: 16, top: 4 })
            .onClick(() => {
              this.descExpanded = true;
            })
        }
        Divider().margin({ top: 12 })
      }
    }
  }

  @Builder
  buildInfoSection() {
    if ((this.comic.tagGroups?.length ?? 0) === 0 &&
      this.comic.stars === undefined &&
      !this.comic.uploader &&
      !this.comic.uploadTime &&
      !this.comic.updateTime &&
      this.comic.maxPage === undefined) {
      Blank()
    } else {
      Column() {
        Text($r('app.string.information'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
          .width('100%')
          .padding({ left: 16, top: 8, bottom: 8 })

        if (this.comic.stars !== undefined) {
          Text(`评分 ${this.comic.stars.toFixed(1)}`)
            .fontSize(14)
            .fontColor(SysTheme.FONT_PRIMARY)
            .padding({ left: 16, bottom: 8 })
        }

        if (this.comic.tagGroups) {
          ForEach(this.comic.tagGroups, (group: ComicTagGroup) => {
            Column() {
              Text(group.namespace)
                .fontSize(12)
                .fontColor(SysTheme.EMPHASIZE)
                .margin({ bottom: 6 })
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(group.tags, (tag: string) => {
                  Text(TagTranslationService.translationTagWithNamespace(tag, group.namespace))
                    .fontSize(11)
                    .fontColor(SysTheme.FONT_PRIMARY)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
                    .borderRadius(12)
                    .margin({ right: 6, bottom: 6 })
                    .onClick(() => this.searchTag(group.namespace, tag))
                }, (tag: string) => `${group.namespace}_${tag}`)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
          }, (group: ComicTagGroup) => group.namespace)
        } else if (this.displayTags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.displayTags, (tag: string) => {
              Text(tag)
                .fontSize(11)
                .fontColor(SysTheme.EMPHASIZE)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
                .borderRadius(8)
                .margin({ right: 6, bottom: 6 })
            }, (tag: string) => tag)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }

        if (this.comic.uploader) {
          Text(`上传者 ${this.comic.uploader}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, bottom: 4 })
        }
        if (this.comic.uploadTime) {
          Text(`上传 ${this.formatTime(this.comic.uploadTime)}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, bottom: 4 })
        }
        if (this.comic.updateTime) {
          Text(`更新 ${this.formatTime(this.comic.updateTime)}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, bottom: 4 })
        }
        if (this.comic.maxPage !== undefined) {
          Text(`页数 ${this.comic.maxPage}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, bottom: 4 })
        }
        Divider().margin({ top: 8 })
      }
    }
  }

  @Builder
  buildChapters() {
    if (this.chapters.length === 0 && this.chapterHint.length > 0) {
      Text(this.chapterHint)
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding(16)
    } else if (this.chapters.length > 0) {
      Column() {
        Row() {
          Text($r('app.string.chapters'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.FONT_PRIMARY)
            .layoutWeight(1)
          SymbolGlyph(this.chapterReversed ?
            $r('sys.symbol.arrow_up') : $r('sys.symbol.arrow_down'))
            .fontSize(18)
            .fontColor([SysTheme.FONT_SECONDARY])
            .onClick(() => {
              this.chapterReversed = !this.chapterReversed;
            })
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (!this.showAllChapters && this.chapters.length > ComicDetailPage.CHAPTER_PREVIEW) {
          Text('显示全部章节')
            .fontSize(13)
            .fontColor(SysTheme.EMPHASIZE)
            .padding(16)
            .onClick(() => {
              this.showAllChapters = true;
            })
        }

        ForEach(this.displayChapters(), (ch: ComicChapter) => {
          Row() {
            Text(ch.title)
              .fontSize(15)
              .layoutWeight(1)
              .onClick(() => this.openReader(ch))
            if (this.downloadingChapterId === ch.id) {
              LoadingProgress().width(24).height(24)
            } else {
              Button('下载')
                .type(ButtonType.Capsule)
                .height(28)
                .fontSize(12)
                .onClick(() => this.downloadChapter(ch))
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }, (ch: ComicChapter) => `row_${ch.id}`)
      }
    }
  }

  @Builder
  buildCommentsPreview() {
    if (this.comments.length > 0) {
      Column() {
        Row() {
          Text($r('app.string.comments'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .layoutWeight(1)
          Text('查看全部')
            .fontSize(13)
            .fontColor(SysTheme.EMPHASIZE)
            .onClick(() => this.openCommentsPage())
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        ForEach(this.comments.slice(0, 4), (c: ComicComment) => {
          Column() {
            Text(c.userName.length > 0 ? c.userName : '匿名')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(SysTheme.FONT_PRIMARY)
            Text(c.content)
              .fontSize(13)
              .fontColor(SysTheme.FONT_SECONDARY)
              .margin({ top: 4 })
              .maxLines(3)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
        }, (c: ComicComment) => c.id.length > 0 ? c.id : `${c.userName}_${c.time}`)
      }
    }
  }

  @Builder
  buildRecommend() {
    if (this.recommend.length > 0) {
      Column() {
        Text($r('app.string.related'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, top: 8, bottom: 8 })
        ForEach(this.recommend.slice(0, 8), (rc: Comic) => {
          ComicListRow({
            comic: rc,
            onItemClick: () => this.openRecommendComic(rc)
          })
        }, (rc: Comic) => `${rc.sourceKey}_${rc.id}`)
      }
    }
  }

  @Builder
  buildMoreMenuOverlay() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showMoreMenu = false;
        })

      Column() {
        Text($r('app.string.copy_title'))
          .fontSize(15)
          .padding(14)
          .width('100%')
          .onClick(() => {
            this.showMoreMenu = false;
            this.copyText(this.comic.title, '已复制标题');
          })
        Text($r('app.string.copy_id'))
          .fontSize(15)
          .padding(14)
          .width('100%')
          .onClick(() => {
            this.showMoreMenu = false;
            this.copyText(this.comic.id, '已复制 ID');
          })
        if (this.comic.url && this.comic.url.length > 0) {
          Text($r('app.string.copy_url'))
            .fontSize(15)
            .padding(14)
            .width('100%')
            .onClick(() => {
              this.showMoreMenu = false;
              this.copyText(this.comic.url ?? '', '已复制链接');
            })
          Text($r('app.string.open_in_browser'))
            .fontSize(15)
            .padding(14)
            .width('100%')
            .onClick(() => {
              this.showMoreMenu = false;
              this.openInBrowser();
            })
        }
        Text($r('app.string.cancel'))
          .fontSize(15)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(14)
          .width('100%')
          .onClick(() => {
            this.showMoreMenu = false;
          })
      }
      .width('100%')
      .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }
}
