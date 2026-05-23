import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { HistoryService } from '../../common/services/HistoryService';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { ReadingHistoryEntry } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { ReaderLaunchUtil } from '../../common/utils/ReaderLaunchUtil';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';

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
        SecondaryPageHeader({ title: $r('app.string.history') })

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
                Image(ImageCacheUtil.resolveSync(item.coverPath))
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
              .onClick(() => ReaderLaunchUtil.openFromHistory(item))
            }
          }, (item: ReadingHistoryEntry) => `${item.sourceKey}_${item.comicId}_${item.updatedAt}`)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
