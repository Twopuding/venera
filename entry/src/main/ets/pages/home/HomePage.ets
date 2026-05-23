import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { DownloadService } from '../../common/services/DownloadService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { AppDataService } from '../../common/services/AppDataService';
import { WebDavSyncService } from '../../common/services/WebDavSyncService';
import { LocalComicItem, ReadingHistoryEntry } from '../../common/models/ComicModels';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { ReaderLaunchUtil } from '../../common/utils/ReaderLaunchUtil';
import { HomeSectionCard } from '../../common/components/HomeSectionCard';
import { ENGINE_READY_KEY } from '../../common/constants/StartupKeys';

/**
 * 首页仪表盘 — 对齐 upstream lib/pages/home_page.dart
 * （搜索 / 同步 / 历史 / 本地 / 关注更新 / 漫画源 / 图片收藏）
 */
@Component
export struct HomePage {
  scroller: Scroller = new Scroller();
  @State historyEntries: ReadingHistoryEntry[] = [];
  @State historyCount: number = 0;
  @State localRecent: LocalComicItem[] = [];
  @State localCount: number = 0;
  @State activeDownloads: number = 0;
  @State comicSourceNames: string[] = [];
  @State webdavEnabled: boolean = false;
  @State syncing: boolean = false;
  @State syncError: string = '';
  @State followUpdateCount: number = 0;
  @State imageFavoriteCount: number = 0;
  @StorageLink(ENGINE_READY_KEY) @Watch('onEngineReadyChanged') engineReady: boolean = false;
  private refreshAll = (): void => { this.loadData(); };

  onEngineReadyChanged(): void {
    this.loadComicSourceNames();
  }

  aboutToAppear(): void {
    this.loadData();
    HistoryService.getInstance().onChange(this.refreshAll);
    LocalComicService.getInstance().onChange(this.refreshAll);
    DownloadService.getInstance().onChange(this.refreshAll);
  }

  onPageShow(): void {
    this.loadData();
  }

  private loadData(): void {
    const history = HistoryService.getInstance().getEntries();
    this.historyEntries = history.slice(0, 12);
    this.historyCount = history.length;
    const comics = LocalComicService.getInstance().getComics();
    this.localRecent = comics.slice(0, 12);
    this.localCount = comics.length;
    this.activeDownloads = DownloadService.getInstance().getTasks()
      .filter((t) => t.status === 'pending' || t.status === 'downloading').length;
    this.loadComicSourceNames();
    const settings = AppDataService.getInstance().settings;
    this.webdavEnabled = settings.webdavUrl.trim().length > 0;
    this.followUpdateCount = 0;
    this.imageFavoriteCount = 0;
  }

  private loadComicSourceNames(): void {
    const indexSources = ComicSourceService.getInstance().getSources();
    const names: string[] = [];
    for (let i = 0; i < indexSources.length; i++) {
      const n = indexSources[i].name.length > 0 ? indexSources[i].name : indexSources[i].key;
      names.push(n);
    }
    this.comicSourceNames = names;
  }

  private async importComics(): Promise<void> {
    const ok = await LocalComicService.getInstance().importFromPicker();
    if (ok) {
      this.loadData();
    }
    try {
      promptAction.showToast({
        message: ok ? '导入完成' : '未选择文件或导入失败',
        duration: 2000
      });
    } catch (_e) {
      console.info(`[HomePage] import: ${ok}`);
    }
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.searchBar()

        if (this.webdavEnabled) {
          this.syncSection()
        }

        HomeSectionCard({
          title: $r('app.string.history'),
          count: this.historyCount,
          onHeaderClick: () => router.pushUrl({ url: 'pages/history/HistoryPage' }),
          body: () => { this.historyBody() }
        })

        HomeSectionCard({
          title: $r('app.string.local_section'),
          count: this.localCount,
          onHeaderClick: () => router.pushUrl({ url: 'pages/local/LocalLibraryPage' }),
          body: () => { this.localBody() },
          footer: () => { this.localFooter() }
        })

        HomeSectionCard({
          title: $r('app.string.follow_updates'),
          count: this.followUpdateCount,
          onHeaderClick: () => router.pushUrl({ url: 'pages/follow/FollowUpdatesPage' }),
          body: () => { this.followUpdatesHint() }
        })

        HomeSectionCard({
          title: $r('app.string.comic_sources'),
          count: this.comicSourceNames.length,
          onHeaderClick: () => router.pushUrl({ url: 'pages/sources/ComicSourcePage' }),
          body: () => { this.comicSourcesBody() }
        })

        HomeSectionCard({
          title: $r('app.string.image_favorites'),
          count: this.imageFavoriteCount,
          onHeaderClick: () => router.pushUrl({ url: 'pages/image_favorites/ImageFavoritesPage' }),
          body: () => { this.imageFavoritesHint() }
        })
      }
      .width('100%')
      .padding({
        left: 8,
        right: 8,
        top: 8,
        bottom: ShellInsets.FLOATING_BAR_RESERVE
      })
    }
    .clipContent(ContentClipMode.SAFE_AREA)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  searchBar() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(20)
        .fontColor([SysTheme.FONT_SECONDARY])
        .margin({ left: 16 })
      Text($r('app.string.search'))
        .fontSize(16)
        .fontColor(SysTheme.FONT_SECONDARY)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(48)
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(24)
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
    .onClick(() => router.pushUrl({ url: 'pages/search/SearchPage' }))
  }

  @Builder
  syncSection() {
    Row() {
      SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
        .fontSize(20)
        .fontColor([SysTheme.EMPHASIZE])
      Text($r('app.string.sync_data'))
        .fontSize(15)
        .fontColor(SysTheme.FONT_PRIMARY)
        .margin({ left: 8 })
        .layoutWeight(1)
      if (this.syncing) {
        LoadingProgress().width(20).height(20)
      } else {
        if (this.syncError.length > 0) {
          Text($r('app.string.sync_error'))
            .fontSize(12)
            .fontColor('#FFE53935')
            .margin({ right: 8 })
            .onClick(() => {
              promptAction.showDialog({
                title: $r('app.string.sync_error'),
                message: this.syncError,
                buttons: [{ text: 'OK', color: '#FF0A59F7' }]
              });
            })
        }
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_up_circle'))
            .fontSize(22)
            .fontColor([SysTheme.EMPHASIZE])
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(async () => {
          this.syncing = true;
          this.syncError = '';
          const r = await WebDavSyncService.upload();
          this.syncing = false;
          if (!r.ok) {
            this.syncError = r.message;
          }
          try {
            promptAction.showToast({ message: r.message, duration: 2000 });
          } catch (_e) {
            // ignore
          }
        })
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_down_circle'))
            .fontSize(22)
            .fontColor([SysTheme.EMPHASIZE])
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(async () => {
          this.syncing = true;
          this.syncError = '';
          const r = await WebDavSyncService.download();
          this.syncing = false;
          if (!r.ok) {
            this.syncError = r.message;
          }
          this.loadData();
          try {
            promptAction.showToast({ message: r.message, duration: 2000 });
          } catch (_e) {
            // ignore
          }
        })
      }
    }
    .width('100%')
    .padding(12)
    .margin({ left: 8, right: 8, bottom: 4 })
    .border({
      width: 1,
      color: SysTheme.EMPHASIZE,
      radius: 8
    })
  }

  @Builder
  historyBody() {
    if (this.historyEntries.length > 0) {
      List({ space: 8 }) {
        ForEach(this.historyEntries, (item: ReadingHistoryEntry) => {
          ListItem() {
            this.historyTile(item)
          }
        }, (item: ReadingHistoryEntry) =>
          `${item.sourceKey}_${item.comicId}_${item.updatedAt}`)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(136)
      .padding({ left: 8, right: 8, bottom: 12 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  historyTile(item: ReadingHistoryEntry) {
    Column() {
      Image(ImageCacheUtil.resolveSync(item.coverPath))
        .width(72)
        .height(100)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      Text(item.title)
        .fontSize(11)
        .fontColor(SysTheme.FONT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(72)
        .margin({ top: 4 })
    }
    .width(80)
    .padding({ left: 4, right: 4 })
    .onClick(() => ReaderLaunchUtil.openFromHistory(item))
  }

  @Builder
  localBody() {
    if (this.localRecent.length > 0) {
      List({ space: 8 }) {
        ForEach(this.localRecent, (item: LocalComicItem) => {
          ListItem() {
            this.localTile(item)
          }
        }, (item: LocalComicItem) => item.id)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(136)
      .padding({ left: 8, right: 8 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  localTile(item: LocalComicItem) {
    Column() {
      if (item.coverPath.length > 0) {
        Image(item.coverPath)
          .width(72)
          .height(100)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      } else {
        Column() {
          Text(item.mediaType === 'epub' ? 'EPUB' : (item.mediaType === 'pdf' ? 'PDF' : '?'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
        }
        .width(72)
        .height(100)
        .borderRadius(6)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
        .justifyContent(FlexAlign.Center)
      }
      Text(item.title)
        .fontSize(11)
        .fontColor(SysTheme.FONT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(72)
        .margin({ top: 4 })
    }
    .width(80)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      if (item.chapters.length > 1) {
        router.pushUrl({
          url: 'pages/local/LocalComicDetailPage',
          params: { comicId: item.id }
        });
      } else {
        const hist = HistoryService.getInstance().find(item.id, 'local');
        ReaderLaunchUtil.openLocalComic(item, hist?.chapterId, hist?.pageIndex);
      }
    })
  }

  @Builder
  localFooter() {
    Row() {
      if (this.activeDownloads > 0) {
        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.arrow_down_circle'))
              .fontSize(16)
              .fontColor([SysTheme.EMPHASIZE])
            Text(`${this.activeDownloads} 个任务`)
              .fontSize(13)
              .fontColor(SysTheme.FONT_PRIMARY)
          }
        }
        .type(ButtonType.Capsule)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(() => router.pushUrl({ url: 'pages/download/DownloadPage' }))
      }
      Blank().layoutWeight(1)
      Button($r('app.string.import_local'))
        .type(ButtonType.Capsule)
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .onClick(() => this.importComics())
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 12, top: 4 })
  }

  @Builder
  followUpdatesHint() {
    if (this.followUpdateCount === 0) {
      Text($r('app.string.follow_updates_hint'))
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 12 })
    }
  }

  @Builder
  comicSourcesBody() {
    if (this.comicSourceNames.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.comicSourceNames, (name: string) => {
          Text(name)
            .fontSize(12)
            .fontColor(SysTheme.FONT_PRIMARY)
            .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
            .margin({ right: 8, bottom: 8 })
        }, (name: string) => name)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })
    }
  }

  @Builder
  imageFavoritesHint() {
    if (this.imageFavoriteCount === 0) {
      Text($r('app.string.image_favorites_hint'))
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 12 })
    }
  }
}
