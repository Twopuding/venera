import { router } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { LocalComicItem, ReadingHistoryEntry } from '../../common/models/ComicModels';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';

/** 首页 — 对应 upstream lib/pages/home_page.dart */
@Component
export struct HomePage {
  scroller: Scroller = new Scroller();
  @State comics: LocalComicItem[] = [];
  private libraryListener = (): void => { this.refresh(); };

  aboutToAppear(): void {
    this.refresh();
    LocalComicService.getInstance().onChange(this.libraryListener);
  }

  aboutToDisappear(): void {
    // listener kept for session; lightweight
  }

  onPageShow(): void {
    this.refresh();
  }

  refresh(): void {
    this.comics = LocalComicService.getInstance().getComics();
  }

  private openReader(item: LocalComicItem, chapterId?: string, pageIndex?: number): void {
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

  build() {
    Scroll(this.scroller) {
      Column() {
        if (HistoryService.getInstance().getEntries().length > 0) {
          Text($r('app.string.continue_reading'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.FONT_PRIMARY)
            .width('100%')
            .margin({ bottom: 8 })
          List() {
            ForEach(HistoryService.getInstance().getEntries().slice(0, 3),
              (item: ReadingHistoryEntry) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Image(item.coverPath)
                      .width(40)
                      .height(56)
                      .borderRadius(4)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
                    Column() {
                      Text(item.title)
                        .fontSize(14)
                        .fontColor(SysTheme.FONT_PRIMARY)
                        .maxLines(1)
                      Text(`第 ${item.pageIndex + 1} 页`)
                        .fontSize(11)
                        .fontColor(SysTheme.FONT_SECONDARY)
                        .margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .padding({ top: 4, bottom: 4 })
                  .onClick(() => {
                    if (item.sourceKey === 'local') {
                      const comic = LocalComicService.getInstance().getComicById(item.comicId);
                      if (comic) {
                        this.openReader(comic, item.chapterId, item.pageIndex);
                      }
                    } else {
                      router.pushUrl({
                        url: 'pages/reader/ReaderPage',
                        params: {
                          comicId: item.comicId,
                          sourceKey: item.sourceKey,
                          title: item.title,
                          chapterId: item.chapterId,
                          pageIndex: String(item.pageIndex)
                        }
                      });
                    }
                  })
                }
              }, (item: ReadingHistoryEntry) =>
                `${item.sourceKey}_${item.comicId}_${item.updatedAt}`)
          }
          .width('100%')
          .margin({ bottom: 16 })
        }

        if (this.comics.length === 0) {
          Column() {
            Text($r('app.string.empty_local'))
              .fontSize(14)
              .fontColor(SysTheme.FONT_SECONDARY)
              .textAlign(TextAlign.Center)
            Button($r('app.string.import_local'))
              .type(ButtonType.Capsule)
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .margin({ top: 16 })
              .onClick(() => router.pushUrl({ url: 'pages/local/LocalLibraryPage' }))
          }
          .width('100%')
          .constraintSize({ minHeight: 320 })
          .justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.comics, (item: LocalComicItem) => {
              GridItem() {
                this.comicCard(item)
              }
            }, (item: LocalComicItem) => item.id)
          }
          .columnsTemplate('1fr 1fr')
          .rowsGap(12)
          .columnsGap(12)
          .width('100%')
        }

        Row({ space: 12 }) {
          Button($r('app.string.downloads'))
            .type(ButtonType.Capsule)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .layoutWeight(1)
            .onClick(() => router.pushUrl({ url: 'pages/download/DownloadPage' }))
          Button($r('app.string.comic_sources'))
            .type(ButtonType.Capsule)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .layoutWeight(1)
            .onClick(() => router.pushUrl({ url: 'pages/sources/ComicSourcePage' }))
        }
        .width('100%')
        .margin({ top: 24 })
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
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
  comicCard(item: LocalComicItem) {
    Column() {
      Image(item.coverPath)
        .width('100%')
        .aspectRatio(0.7)
        .borderRadius(8)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
        .objectFit(ImageFit.Cover)
      Text(item.title)
        .fontSize(13)
        .fontColor(SysTheme.FONT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
      if (item.pageCount > 0) {
        Text(`${item.pageCount} 页`)
          .fontSize(11)
          .fontColor(SysTheme.FONT_SECONDARY)
      }
    }
    .onClick(() => {
      if (item.chapters.length > 1) {
        router.pushUrl({
          url: 'pages/local/LocalComicDetailPage',
          params: { comicId: item.id }
        });
      } else {
        const hist = HistoryService.getInstance().find(item.id, 'local');
        this.openReader(item, hist?.chapterId, hist?.pageIndex);
      }
    })
  }
}
