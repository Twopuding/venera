import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { LocalComicItem } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { ReaderLaunchUtil } from '../../common/utils/ReaderLaunchUtil';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 本地漫画书架 — 对齐 upstream lib/pages/local_comics_page.dart
 */
@Entry
@Component
struct LocalLibraryPage {
  @State comics: LocalComicItem[] = [];
  @State importing: boolean = false;
  private libraryListener = (): void => { this.refresh(); };

  aboutToAppear(): void {
    this.refresh();
    LocalComicService.getInstance().onChange(this.libraryListener);
  }

  refresh(): void {
    this.comics = LocalComicService.getInstance().getComics();
  }

  private async importComics(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    const ok = await LocalComicService.getInstance().importFromPicker();
    this.importing = false;
    if (ok) {
      this.refresh();
    }
    try {
      promptAction.showToast({
        message: ok ? '导入完成' : '未选择文件或导入失败',
        duration: 2000
      });
    } catch (_e) {
      console.info(`[LocalLibraryPage] import: ${ok}`);
    }
  }

  private confirmRemove(item: LocalComicItem): void {
    promptAction.showDialog({
      title: $r('app.string.remove_local_comic'),
      message: $r('app.string.remove_local_confirm'),
      buttons: [
        { text: $r('app.string.cancel'), color: '#99000000' },
        { text: $r('app.string.remove_local_comic'), color: '#FFE53935' }
      ]
    }).then(async (data) => {
      if (data.index === 1) {
        const ok = await LocalComicService.getInstance().removeComic(item.id);
        if (ok) {
          this.refresh();
        }
      }
    }).catch(() => {
      // dismissed
    });
  }

  build() {
    Column() {
        SecondaryPageHeader({ title: $r('app.string.local_library') })

        Row({ space: 8 }) {
        Button($r('app.string.import_local'))
          .type(ButtonType.Capsule)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .enabled(!this.importing)
          .onClick(() => this.importComics())
        Button($r('app.string.scan_library'))
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .enabled(!this.importing)
          .onClick(async () => {
            await LocalComicService.getInstance().scanLibrary();
            this.refresh();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (this.importing) {
        LoadingProgress().width(32).height(32).margin({ bottom: 8 })
      }

      if (this.comics.length === 0) {
        Column() {
          Text($r('app.string.empty_local'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
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
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  comicCard(item: LocalComicItem) {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (item.coverPath.length > 0) {
          Image(item.coverPath)
            .width('100%')
            .aspectRatio(0.7)
            .borderRadius(8)
            .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text(item.mediaType === 'epub' ? 'EPUB' : (item.mediaType === 'pdf' ? 'PDF' : '?'))
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(SysTheme.FONT_SECONDARY)
          }
          .width('100%')
          .aspectRatio(0.7)
          .borderRadius(8)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
          .justifyContent(FlexAlign.Center)
        }
        if (item.mediaType === 'pdf' || item.mediaType === 'epub') {
          Text(item.mediaType === 'pdf' ? $r('app.string.media_pdf') : $r('app.string.media_epub'))
            .fontSize(10)
            .fontColor('#FFFFFFFF')
            .backgroundColor('#99000000')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin(6)
        }
      }
      Text(item.title)
        .fontSize(13)
        .fontColor(SysTheme.FONT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
      if (item.pageCount > 0) {
        Text(item.mediaType === 'epub' ?
          `${item.chapterCount} 章` : `${item.pageCount} 页`)
          .fontSize(11)
          .fontColor(SysTheme.FONT_SECONDARY)
      }
    }
    .gesture(
      LongPressGesture()
        .onAction(() => this.confirmRemove(item))
    )
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
}
