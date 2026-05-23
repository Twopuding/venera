import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { SysTheme } from '../../common/theme/SysTheme';
import { EpubParseUtil } from '../../common/utils/EpubParseUtil';
import { LocalComicService } from '../../common/services/LocalComicService';
import { HistoryService } from '../../common/services/HistoryService';
import { ReadingHistoryEntry } from '../../common/models/ComicModels';

/** 本地 EPUB 章节阅读 — API 23 ArkWeb 渲染 XHTML */
@Entry
@Component
struct EpubReaderPage {
  @State title: string = 'EPUB';
  @State pageUrl: string = '';
  @State loadError: string = '';
  @State chapterIndex: number = 0;
  @State chapterLabels: string[] = [];
  private webController: webview.WebviewController = new webview.WebviewController();
  private comicId: string = '';
  private chapterPaths: string[] = [];
  private chapterIds: string[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? 'EPUB';
    this.comicId = params['comicId'] ?? '';
    const startPath = params['chapterPath'] ?? '';
    const comic = LocalComicService.getInstance().getComicById(this.comicId);
    if (comic && comic.mediaType === 'epub' && comic.chapters.length > 0) {
      this.chapterPaths = comic.chapters.map((c) => c.directory);
      this.chapterIds = comic.chapters.map((c) => c.id);
      this.chapterLabels = comic.chapters.map((c) => c.title);
      const idx = this.chapterPaths.indexOf(startPath);
      this.chapterIndex = idx >= 0 ? idx : 0;
    } else if (startPath.length > 0) {
      this.chapterPaths = [startPath];
      this.chapterIds = ['0'];
      this.chapterLabels = ['第 1 章'];
      this.chapterIndex = 0;
    }
    this.loadChapter(this.chapterIndex);
  }

  private loadChapter(index: number): void {
    if (index < 0 || index >= this.chapterPaths.length) {
      this.loadError = '章节不存在';
      return;
    }
    this.chapterIndex = index;
    const path = this.chapterPaths[index];
    try {
      this.pageUrl = EpubParseUtil.chapterFileUrl(path);
      this.loadError = '';
      this.saveProgress();
    } catch (e) {
      this.loadError = `无法加载章节：${e}`;
    }
  }

  private async saveProgress(): Promise<void> {
    if (this.comicId.length === 0) {
      return;
    }
    const entry = new ReadingHistoryEntry();
    entry.comicId = this.comicId;
    entry.sourceKey = 'local';
    entry.title = this.title;
    entry.directory = LocalComicService.getInstance().getComicById(this.comicId)?.directory ?? '';
    entry.chapterId = this.chapterIds[this.chapterIndex] ?? '';
    entry.coverPath = '';
    entry.pageIndex = this.chapterIndex;
    await HistoryService.getInstance().record(entry);
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button('关闭')
          .onClick(() => {
            this.saveProgress();
            router.back();
          })
      }
      .padding(12)

      if (this.chapterLabels.length > 0) {
        Text(this.chapterLabels[this.chapterIndex] ?? '')
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 12, right: 12, bottom: 8 })
      }

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else if (this.pageUrl.length > 0) {
        Web({ src: this.pageUrl, controller: this.webController })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(true)
          .layoutWeight(1)
          .width('100%')
      }

      if (this.chapterPaths.length > 1) {
        Row({ space: 12 }) {
          Button('上一章')
            .layoutWeight(1)
            .enabled(this.chapterIndex > 0)
            .onClick(() => this.loadChapter(this.chapterIndex - 1))
          Button('下一章')
            .layoutWeight(1)
            .enabled(this.chapterIndex < this.chapterPaths.length - 1)
            .onClick(() => this.loadChapter(this.chapterIndex + 1))
        }
        .padding(12)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
