import { router } from '@kit.ArkUI';
import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import { SysTheme } from '../../common/theme/SysTheme';
import { HistoryService } from '../../common/services/HistoryService';
import { ReadingHistoryEntry } from '../../common/models/ComicModels';

/** 本地 PDF 阅读 — API 23 @kit.PDFKit PdfView */
@Entry
@Component
struct PdfReaderPage {
  @State title: string = 'PDF';
  @State loadError: string = '';
  private pdfPath: string = '';
  private comicId: string = '';
  private pdfController: pdfViewManager.PdfController = new pdfViewManager.PdfController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? 'PDF';
    this.pdfPath = params['pdfPath'] ?? '';
    this.comicId = params['comicId'] ?? '';
    this.loadPdf();
    this.saveProgress();
  }

  private loadPdf(): void {
    if (this.pdfPath.length === 0) {
      this.loadError = '未指定 PDF 路径';
      return;
    }
    (async () => {
      try {
        const result = await this.pdfController.loadDocument(this.pdfPath);
        console.info(`[PdfReaderPage] loaded: ${JSON.stringify(result)}`);
      } catch (e) {
        this.loadError = `无法打开 PDF：${e}`;
      }
    })();
  }

  private async saveProgress(): Promise<void> {
    if (this.comicId.length === 0) {
      return;
    }
    const entry = new ReadingHistoryEntry();
    entry.comicId = this.comicId;
    entry.sourceKey = 'local';
    entry.title = this.title;
    entry.directory = this.pdfPath;
    entry.chapterId = '';
    entry.coverPath = '';
    entry.pageIndex = 0;
    await HistoryService.getInstance().record(entry);
  }

  build() {
    Column() {
      Row() {
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

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        PdfView({
          controller: this.pdfController,
          pageFit: pdfService.PageFit.FIT_WIDTH,
          showScroll: true
        })
          .layoutWeight(1)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
