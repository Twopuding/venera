import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { Comic, ComicChapter, ComicComment, DownloadTask } from '../../common/models/ComicModels';
import { FavoritesService } from '../../common/services/FavoritesService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { DownloadService } from '../../common/services/DownloadService';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { ComicImageResolver } from '../../common/utils/ComicImageResolver';
import { SysTheme } from '../../common/theme/SysTheme';
import { TagTranslationService } from '../../common/services/TagTranslationService';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

@Entry
@Component
struct ComicDetailPage {
  @State comic: Comic = new Comic();
  @State isFavorite: boolean = false;
  @State chapters: ComicChapter[] = [];
  @State comments: ComicComment[] = [];
  @State recommend: Comic[] = [];
  @State loadingChapters: boolean = false;
  @State chapterHint: string = '';
  @State downloadingChapterId: string = '';
  @State coverSrc: string = '';
  @State displayTitle: string = '';
  @State displayDescription: string = '';
  @State displayTags: string[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params['comicJson']) {
      this.comic = JSON.parse(params['comicJson']) as Comic;
      this.applyDisplayFields();
      this.isFavorite = FavoritesService.getInstance()
        .isFavorite(this.comic.id, this.comic.sourceKey);
      this.resolveCover();
      this.loadComicDetails();
    }
  }

  private applyDisplayFields(): void {
    this.displayTitle = TagTranslationService.translateTagLine(this.comic.title);
    this.displayDescription = TagTranslationService.translateTagLine(this.comic.description);
    this.displayTags = [];
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
    if (from.subtitle) {
      this.comic.subtitle = from.subtitle;
    }
    if (from.stars !== undefined) {
      this.comic.stars = from.stars;
    }
    this.applyDisplayFields();
    this.resolveCover();
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
      return;
    }
    this.loadingChapters = true;
    const info = await JsEngineBridge.getInstance()
      .invokeComicInfo(this.comic.sourceKey, this.comic.id);
    this.mergeComicInfo(info.comic);
    this.chapters = info.chapters;
    this.comments = info.comments;
    this.recommend = info.recommend;
    const status = JsEngineBridge.getInstance().getStatus();
    this.chapterHint = this.chapters.length > 0 ? '' :
      (status.runtimeReady ? '章节列表为空，请检查漫画源或登录状态' : status.runtimeNote);
    this.loadingChapters = false;
  }

  private openReader(chapter: ComicChapter): void {
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: this.comic.id,
        sourceKey: this.comic.sourceKey,
        title: `${this.comic.title} · ${chapter.title}`,
        chapterId: chapter.id,
        coverPath: this.comic.cover
      }
    });
  }

  private openRecommendComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
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

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.displayTitle.length > 0 ? this.displayTitle : this.comic.title
      })

      Scroll() {
        Column() {
          Image(this.coverSrc.length > 0 ? this.coverSrc : this.comic.cover)
          .width('100%')
          .height(220)
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
        Text(this.displayTitle.length > 0 ? this.displayTitle : this.comic.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(SysTheme.FONT_PRIMARY)
          .padding({ left: 16, right: 16, top: 16 })
        if (this.comic.subtitle && this.comic.subtitle.length > 0) {
          Text(this.comic.subtitle)
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, right: 16, top: 4 })
        }
        if (this.displayTags.length > 0) {
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
          .padding({ left: 16, right: 16, top: 8 })
        }
        Text(this.displayDescription.length > 0 ? this.displayDescription : this.comic.description)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, top: 8 })
          .maxLines(8)

        Row({ space: 12 }) {
          Button(this.isFavorite ? '取消收藏' : '收藏')
            .layoutWeight(1)
            .onClick(async () => {
              if (this.isFavorite) {
                await FavoritesService.getInstance().remove(this.comic.id, this.comic.sourceKey);
                this.isFavorite = false;
              } else {
                await FavoritesService.getInstance().add(this.comic);
                this.isFavorite = true;
              }
            })
          Button('开始阅读')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .layoutWeight(1)
            .enabled(this.chapters.length > 0)
            .onClick(() => {
              if (this.chapters.length > 0) {
                this.openReader(this.chapters[0]);
              }
            })
        }
        .padding(16)

        if (this.loadingChapters) {
          LoadingProgress().width(32).height(32).margin({ left: 16 })
        } else if (this.chapters.length > 0) {
          Text('章节')
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, bottom: 8 })
          ForEach(this.chapters, (ch: ComicChapter) => {
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
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          }, (ch: ComicChapter) => ch.id)
        } else if (this.chapterHint.length > 0) {
          Text(this.chapterHint)
            .fontSize(12)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }

        if (this.comments.length > 0) {
          Text('评论')
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, top: 16, bottom: 8 })
          ForEach(this.comments.slice(0, 8), (c: ComicComment) => {
            Column() {
              Text(c.userName.length > 0 ? c.userName : '匿名')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(SysTheme.FONT_PRIMARY)
              Text(c.content)
                .fontSize(13)
                .fontColor(SysTheme.FONT_SECONDARY)
                .margin({ top: 4 })
                .maxLines(4)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 12 })
          }, (c: ComicComment) => c.id.length > 0 ? c.id : `${c.userName}_${c.time}`)
        }

        if (this.recommend.length > 0) {
          Text('相关推荐')
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, top: 8, bottom: 8 })
          ForEach(this.recommend.slice(0, 6), (rc: Comic) => {
            ComicListRow({
              comic: rc,
              onItemClick: () => this.openRecommendComic(rc)
            })
          }, (rc: Comic) => `${rc.sourceKey}_${rc.id}`)
        }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
