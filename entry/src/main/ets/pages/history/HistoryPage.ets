import { router } from '@kit.ArkUI';
import { HistoryService } from '../../common/services/HistoryService';
import { ReadingHistoryEntry } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';

/** 阅读历史 — 对应 upstream lib/pages/history_page.dart */
@Entry
@Component
struct HistoryPage {
  @State entries: ReadingHistoryEntry[] = [];

  aboutToAppear(): void {
    this.refresh();
    HistoryService.getInstance().onChange(() => { this.refresh(); });
  }

  refresh(): void {
    this.entries = HistoryService.getInstance().getEntries();
  }

  build() {
    Column() {
      Text($r('app.string.history'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)

      if (this.entries.length === 0) {
        Text($r('app.string.empty_history'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.entries, (item: ReadingHistoryEntry) => {
            ListItem() {
              Row({ space: 12 }) {
                Image(item.coverPath)
                  .width(48)
                  .height(64)
                  .borderRadius(4)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
                Column() {
                  Text(item.title)
                    .fontSize(15)
                    .fontColor(SysTheme.FONT_PRIMARY)
                    .maxLines(2)
                  Text(`第 ${item.pageIndex + 1} 页`)
                    .fontSize(12)
                    .fontColor(SysTheme.FONT_SECONDARY)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .padding(12)
              .onClick(() => router.pushUrl({
                url: 'pages/reader/ReaderPage',
                params: {
                  comicId: item.comicId,
                  sourceKey: item.sourceKey,
                  title: item.title,
                  directory: item.directory,
                  coverPath: item.coverPath,
                  chapterId: item.chapterId,
                  pageIndex: String(item.pageIndex)
                }
              }))
            }
          }, (item: ReadingHistoryEntry) => `${item.sourceKey}_${item.comicId}_${item.updatedAt}`)
        }
        .layoutWeight(1)
      }

      Button('返回')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .margin(16)
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
