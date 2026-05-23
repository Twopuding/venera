import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { LocalComicChapter, LocalComicItem } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { ReaderLaunchUtil } from '../../common/utils/ReaderLaunchUtil';

/** 本地漫画详情 — 多章节选择后进入阅读器 */
@Entry
@Component
struct LocalComicDetailPage {
  @State comic: LocalComicItem | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    const id = params['comicId'] ?? '';
    this.comic = LocalComicService.getInstance().getComicById(id) ?? null;
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.comic ? this.comic.title : '本地漫画'
      })

      if (this.comic) {
        Image(this.comic.coverPath)
          .width('100%')
          .height(200)
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
        Text(this.comic.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(SysTheme.FONT_PRIMARY)
          .padding(16)
        Text(`${this.comic.pageCount} 页 · ${this.comic.chapterCount} 章`)
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })

        List() {
          if (this.comic.chapters.length > 0) {
            ForEach(this.comic.chapters, (ch: LocalComicChapter) => {
              ListItem() {
                Row() {
                  Text(ch.title)
                    .fontSize(15)
                    .fontColor(SysTheme.FONT_PRIMARY)
                    .layoutWeight(1)
                  Text(`${ch.pageCount} 页`)
                    .fontSize(12)
                    .fontColor(SysTheme.FONT_SECONDARY)
                }
                .width('100%')
                .padding(14)
                .onClick(() => {
                  const hist = HistoryService.getInstance().find(this.comic!.id, 'local');
                  const page = (hist?.chapterId === ch.id) ? (hist?.pageIndex ?? 0) : 0;
                  ReaderLaunchUtil.openLocalComic(this.comic!, ch.id, page);
                })
              }
            }, (ch: LocalComicChapter) => ch.id)
          } else {
            ListItem() {
              Text('开始阅读')
                .fontSize(15)
                .padding(14)
                .onClick(() => {
                  const hist = HistoryService.getInstance().find(this.comic!.id, 'local');
                  ReaderLaunchUtil.openLocalComic(this.comic!, hist?.chapterId, hist?.pageIndex);
                })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Text('漫画不存在或已被移除')
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
