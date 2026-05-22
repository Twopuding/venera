import { router } from '@kit.ArkUI';
import { SysTheme } from '../../common/theme/SysTheme';
import { LocalImageUtil } from '../../common/utils/LocalImageUtil';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { HistoryService } from '../../common/services/HistoryService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ReadingHistoryEntry } from '../../common/models/ComicModels';

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
      this.pagePaths = await JsEngineBridge.getInstance()
        .invokeComicPages(this.sourceKey, this.comicId, this.chapterId);
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
          ForEach(this.displayPaths, (path: string) => {
            Image(path)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .backgroundColor('#FF000000')
              .draggable(false)
          }, (path: string) => path)
        }
        .width('100%')
        .height('100%')
        .index(this.currentPage)
        .indicator(false)
        .onChange((index: number) => {
          this.currentPage = index;
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

      if (this.showChrome) {
        Column() {
          Row() {
            Button($r('app.string.reader_prev'))
              .onClick(() => {
                if (this.currentPage > 0) {
                  this.currentPage--;
                  this.swiperCtrl.changeIndex(this.currentPage, true);
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
                  this.saveProgress();
                }
              })
          }
          .padding(12)
          .backgroundColor('#CC1A1A1A')

          Text(this.title)
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
