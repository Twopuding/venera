import { router } from '@kit.ArkUI';
import { Comic, ComicChapter, DownloadTask } from '../../common/models/ComicModels';
import { FavoritesService } from '../../common/services/FavoritesService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { DownloadService } from '../../common/services/DownloadService';
import { SysTheme } from '../../common/theme/SysTheme';

@Entry
@Component
struct ComicDetailPage {
  @State comic: Comic = new Comic();
  @State isFavorite: boolean = false;
  @State chapters: ComicChapter[] = [];
  @State loadingChapters: boolean = false;
  @State chapterHint: string = '';
  @State downloadingChapterId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params['comicJson']) {
      this.comic = JSON.parse(params['comicJson']) as Comic;
      this.isFavorite = FavoritesService.getInstance()
        .isFavorite(this.comic.id, this.comic.sourceKey);
      this.loadChapters();
    }
  }

  private async loadChapters(): Promise<void> {
    if (this.comic.sourceKey.length === 0 || this.comic.id.length === 0) {
      return;
    }
    this.loadingChapters = true;
    this.chapters = await JsEngineBridge.getInstance()
      .invokeComicChapters(this.comic.sourceKey, this.comic.id);
    const status = JsEngineBridge.getInstance().getStatus();
    this.chapterHint = this.chapters.length > 0 ? '' :
      (status.runtimeReady ? '章节列表为空，请检查漫画源或登录状态' : status.runtimeNote);
    this.loadingChapters = false;
  }

  private openReader(chapter: ComicChapter): void {
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: this.comic.id,
        sourceKey: this.comic.sourceKey,
        title: `${this.comic.title} · ${chapter.title}`,
        chapterId: chapter.id,
        coverPath: this.comic.cover
      }
    });
  }

  private async downloadChapter(chapter: ComicChapter): Promise<void> {
    if (this.downloadingChapterId.length > 0) {
      return;
    }
    this.downloadingChapterId = chapter.id;
    const pages = await JsEngineBridge.getInstance()
      .invokeComicPages(this.comic.sourceKey, this.comic.id, chapter.id);
    if (pages.length === 0) {
      this.downloadingChapterId = '';
      return;
    }
    const baseId = `${this.comic.sourceKey}_${this.comic.id}_${chapter.id}`;
    for (let i = 0; i < pages.length; i++) {
      const url = pages[i];
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        continue;
      }
      const task = new DownloadTask();
      task.id = `${baseId}_${i}`;
      task.comicTitle = this.comic.title;
      task.chapterTitle = `${chapter.title} #${i + 1}`;
      task.sourceKey = this.comic.sourceKey;
      task.resourceUrl = url;
      task.status = 'pending';
      await DownloadService.getInstance().enqueue(task);
    }
    this.downloadingChapterId = '';
    router.pushUrl({ url: 'pages/download/DownloadPage' });
  }

  build() {
    Column() {
      Image(this.comic.cover)
        .width('100%')
        .height(220)
        .objectFit(ImageFit.Cover)
        .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      Text(this.comic.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)
      Text(this.comic.description)
        .fontSize(14)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16 })
        .maxLines(6)

      Row({ space: 12 }) {
        Button(this.isFavorite ? '取消收藏' : '收藏')
          .layoutWeight(1)
          .onClick(async () => {
            if (this.isFavorite) {
              await FavoritesService.getInstance().remove(this.comic.id, this.comic.sourceKey);
              this.isFavorite = false;
            } else {
              await FavoritesService.getInstance().add(this.comic);
              this.isFavorite = true;
            }
          })
        Button('开始阅读')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .enabled(this.chapters.length > 0)
          .onClick(() => {
            if (this.chapters.length > 0) {
              this.openReader(this.chapters[0]);
            }
          })
      }
      .padding(16)

      if (this.loadingChapters) {
        LoadingProgress().width(32).height(32).margin({ left: 16 })
      } else if (this.chapters.length > 0) {
        Text('章节')
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, bottom: 8 })
        List() {
          ForEach(this.chapters, (ch: ComicChapter) => {
            ListItem() {
              Row() {
                Text(ch.title)
                  .fontSize(15)
                  .layoutWeight(1)
                  .onClick(() => this.openReader(ch))
                if (this.downloadingChapterId === ch.id) {
                  LoadingProgress().width(24).height(24)
                } else {
                  Button('下载')
                    .type(ButtonType.Capsule)
                    .height(28)
                    .fontSize(12)
                    .onClick(() => this.downloadChapter(ch))
                }
              }
              .width('100%')
              .padding(12)
            }
          }, (ch: ComicChapter) => ch.id)
        }
        .layoutWeight(1)
      } else if (this.chapterHint.length > 0) {
        Text(this.chapterHint)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        Blank().layoutWeight(1)
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
