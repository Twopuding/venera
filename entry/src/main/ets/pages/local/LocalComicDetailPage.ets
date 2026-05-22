import { router } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { LocalComicChapter, LocalComicItem } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';

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

  private openReader(chapterId: string, pageIndex: number): void {
    if (!this.comic) {
      return;
    }
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: this.comic.id,
        sourceKey: 'local',
        title: this.comic.title,
        directory: this.comic.directory,
        coverPath: this.comic.coverPath,
        chapterId: chapterId,
        pageIndex: String(pageIndex)
      }
    });
  }

  build() {
    Column() {
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
                  this.openReader(ch.id, page);
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
                  this.openReader(hist?.chapterId ?? '', hist?.pageIndex ?? 0);
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

      Button('返回')
        .margin(16)
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
