import { router } from '@kit.ArkUI';
import { SysTheme } from '../../common/theme/SysTheme';
import { LocalImageUtil } from '../../common/utils/LocalImageUtil';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { ComicImageResolver } from '../../common/utils/ComicImageResolver';
import { HistoryService } from '../../common/services/HistoryService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { LocalComicService } from '../../common/services/LocalComicService';
import { AppDataService } from '../../common/services/AppDataService';
import { LocalComicChapter, ReadingHistoryEntry } from '../../common/models/ComicModels';

/** 阅读器 — 对应 upstream lib/pages/reader/* */
@Entry
@Component
struct ReaderPage {
  @State title: string = '';
  @State currentPage: number = 0;
  @State pagePaths: string[] = [];
  @State displayPaths: string[] = [];
  @State showChrome: boolean = true;
  @State loadingRemote: boolean = false;
  @State loadError: string = '';
  @State isVertical: boolean = true;
  @State localChapters: LocalComicChapter[] = [];
  @State showChapterPicker: boolean = false;
  private swiperCtrl: SwiperController = new SwiperController();
  private comicId: string = '';
  private sourceKey: string = 'local';
  private directory: string = '';
  private chapterId: string = '';
  private coverPath: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? '阅读';
    this.comicId = params['comicId'] ?? '';
    this.sourceKey = params['sourceKey'] ?? 'local';
    this.directory = params['directory'] ?? '';
    this.chapterId = params['chapterId'] ?? '';
    this.coverPath = params['coverPath'] ?? '';
    this.isVertical = AppDataService.getInstance().settings.readerMode !== 'horizontal';
    if (this.sourceKey === 'local' && this.comicId.length > 0) {
      const comic = LocalComicService.getInstance().getComicById(this.comicId);
      if (comic && comic.chapters.length > 0) {
        this.localChapters = comic.chapters;
        this.directory = comic.directory;
        if (this.chapterId.length === 0 && comic.lastReadChapterId) {
          this.chapterId = comic.lastReadChapterId;
        }
      }
    }
    const startPage = Number(params['pageIndex'] ?? '0');
    this.bootstrapReader(startPage);
  }

  private async bootstrapReader(startPage: number): Promise<void> {
    await this.loadPages();
    if (!isNaN(startPage) && startPage >= 0 && startPage < this.pagePaths.length) {
      this.currentPage = startPage;
      this.swiperCtrl.changeIndex(this.currentPage, false);
    }
    await this.prepareDisplayPaths();
    this.prefetchAround(this.currentPage);
    this.saveProgress();
  }

  private async loadPages(): Promise<void> {
    if (this.directory.length > 0) {
      const readDir = LocalImageUtil.resolveReadingDirectory(this.directory, this.chapterId);
      this.pagePaths = LocalImageUtil.listImageFiles(readDir);
      return;
    }
    const raw = router.getParams() as Record<string, string>;
    const pagesJson = raw['pageUrlsJson'] ?? '';
    if (pagesJson.length > 0) {
      try {
        this.pagePaths = JSON.parse(pagesJson) as string[];
      } catch (_e) {
        this.pagePaths = [];
      }
      return;
    }
    if (this.sourceKey !== 'local' && this.comicId.length > 0 && this.chapterId.length > 0) {
      this.loadingRemote = true;
      this.loadError = '';
      const entries = await JsEngineBridge.getInstance()
        .invokeComicPageEntries(this.sourceKey, this.comicId, this.chapterId);
      this.pagePaths = await ComicImageResolver.resolveAll(entries);
      if (this.pagePaths.length === 0) {
        const status = JsEngineBridge.getInstance().getStatus();
        this.loadError = status.runtimeReady ?
          '未能加载章节图片，请确认漫画源已缓存且已登录' : status.runtimeNote;
      }
      this.loadingRemote = false;
      return;
    }
    this.pagePaths = [];
  }

  private async prepareDisplayPaths(): Promise<void> {
    const hasRemote = this.pagePaths.some((p: string) => ImageCacheUtil.isRemoteUrl(p));
    if (!hasRemote) {
      this.displayPaths = this.pagePaths;
      return;
    }
    this.loadingRemote = true;
    const resolved: string[] = [];
    for (let i = 0; i < this.pagePaths.length; i++) {
      resolved.push(ImageCacheUtil.resolveSync(this.pagePaths[i]));
    }
    this.displayPaths = resolved;
    const cached = await ImageCacheUtil.resolveAll(this.pagePaths);
    this.displayPaths = cached;
    this.loadingRemote = false;
  }

  private prefetchAround(index: number): void {
    const offsets = [index - 1, index + 1, index + 2];
    for (let i = 0; i < offsets.length; i++) {
      const pi = offsets[i];
      if (pi < 0 || pi >= this.pagePaths.length) {
        continue;
      }
      const path = this.pagePaths[pi];
      if (ImageCacheUtil.isRemoteUrl(path)) {
        ImageCacheUtil.ensureCached(path).catch(() => {
          // ignore prefetch errors
        });
      }
    }
  }

  private async switchChapter(chapterId: string): Promise<void> {
    this.chapterId = chapterId;
    this.showChapterPicker = false;
    this.currentPage = 0;
    await this.loadPages();
    await this.prepareDisplayPaths();
    this.swiperCtrl.changeIndex(0, false);
    this.prefetchAround(0);
    this.saveProgress();
  }

  private async saveProgress(): Promise<void> {
    if (this.comicId.length === 0 || this.pagePaths.length === 0) {
      return;
    }
    const entry = new ReadingHistoryEntry();
    entry.comicId = this.comicId;
    entry.sourceKey = this.sourceKey;
    entry.title = this.title;
    entry.directory = this.directory;
    entry.chapterId = this.chapterId;
    entry.coverPath = this.coverPath;
    entry.pageIndex = this.currentPage;
    await HistoryService.getInstance().record(entry);
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.displayPaths.length > 0) {
        Swiper(this.swiperCtrl) {
          ForEach(this.displayPaths, (path: string, index: number) => {
            Image(path)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .backgroundColor('#FF000000')
              .draggable(false)
          }, (path: string, index: number) => `${index}_${path}`)
        }
        .width('100%')
        .height('100%')
        .vertical(this.isVertical)
        .index(this.currentPage)
        .indicator(false)
        .onChange((index: number) => {
          this.currentPage = index;
          this.prefetchAround(index);
          this.saveProgress();
        })
        .onClick(() => { this.showChrome = !this.showChrome; })
      } else if (this.loadingRemote) {
        Column() {
          LoadingProgress().width(48).height(48)
          Text($r('app.string.reader_loading_pages'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text(this.title)
            .fontSize(18)
            .fontColor(SysTheme.FONT_SECONDARY)
          if (this.loadError.length > 0) {
            Text(this.loadError)
              .fontSize(14)
              .margin({ top: 8 })
              .fontColor(SysTheme.FONT_SECONDARY)
          } else {
            Text($r('app.string.reader_no_pages'))
              .fontSize(14)
              .margin({ top: 8 })
              .fontColor(SysTheme.FONT_SECONDARY)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.showChapterPicker && this.localChapters.length > 0) {
        Column() {
          Text('选择章节')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.FONT_PRIMARY)
            .padding(16)
          List() {
            ForEach(this.localChapters, (ch: LocalComicChapter) => {
              ListItem() {
                Row() {
                  Text(ch.title)
                    .fontSize(15)
                    .fontColor(this.chapterId === ch.id ? SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
                    .layoutWeight(1)
                  Text(`${ch.pageCount} 页`)
                    .fontSize(12)
                    .fontColor(SysTheme.FONT_SECONDARY)
                }
                .width('100%')
                .padding(14)
                .onClick(() => { this.switchChapter(ch.id); })
              }
            }, (ch: LocalComicChapter) => ch.id)
          }
          .layoutWeight(1)
          .width('100%')
          Button($r('app.string.cancel'))
            .margin(16)
            .onClick(() => { this.showChapterPicker = false; })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
      }

      if (this.showChrome && !this.showChapterPicker) {
        Column() {
          Row() {
            Button($r('app.string.reader_prev'))
              .onClick(() => {
                if (this.currentPage > 0) {
                  this.currentPage--;
                  this.swiperCtrl.changeIndex(this.currentPage, true);
                  this.prefetchAround(this.currentPage);
                  this.saveProgress();
                }
              })
            Text(`${this.currentPage + 1} / ${Math.max(this.displayPaths.length, 1)}`)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .fontColor(SysTheme.FONT_PRIMARY)
            Button($r('app.string.reader_next'))
              .onClick(() => {
                if (this.currentPage < this.displayPaths.length - 1) {
                  this.currentPage++;
                  this.swiperCtrl.changeIndex(this.currentPage, true);
                  this.prefetchAround(this.currentPage);
                  this.saveProgress();
                }
              })
          }
          .padding(12)
          .backgroundColor('#CC1A1A1A')

          if (this.displayPaths.length > 1) {
            Slider({
              value: this.currentPage,
              min: 0,
              max: Math.max(this.displayPaths.length - 1, 0),
              step: 1
            })
              .blockColor(SysTheme.EMPHASIZE)
              .trackColor('#44FFFFFF')
              .selectedColor(SysTheme.EMPHASIZE)
              .margin({ left: 16, right: 16, bottom: 4 })
              .onChange((value: number) => {
                const idx = Math.round(value);
                if (idx !== this.currentPage && idx >= 0 && idx < this.displayPaths.length) {
                  this.currentPage = idx;
                  this.swiperCtrl.changeIndex(this.currentPage, false);
                  this.prefetchAround(this.currentPage);
                  this.saveProgress();
                }
              })
          }

          Row({ space: 8 }) {
            if (this.localChapters.length > 1) {
              Button('章节')
                .onClick(() => { this.showChapterPicker = true; })
            }
            Text(this.title)
              .fontSize(14)
              .fontColor(SysTheme.FONT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .padding({ left: 16, right: 16, bottom: 8 })

          Button('关闭')
            .margin({ left: 16, right: 16, bottom: 16 })
            .onClick(() => {
              this.saveProgress();
              router.back();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FF000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
