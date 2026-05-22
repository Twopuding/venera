import { router } from '@kit.ArkUI';
import { DownloadService } from '../../common/services/DownloadService';
import { DownloadTask } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';

@Entry
@Component
struct DownloadPage {
  @State tasks: DownloadTask[] = [];

  aboutToAppear(): void {
    this.tasks = DownloadService.getInstance().getTasks();
    DownloadService.getInstance().onChange(() => {
      this.tasks = DownloadService.getInstance().getTasks();
    });
  }

  build() {
    Column() {
      Text($r('app.string.downloads'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)

      if (this.tasks.length === 0) {
        Text($r('app.string.empty_downloads'))
          .fontColor(SysTheme.FONT_SECONDARY)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.tasks, (task: DownloadTask) => {
            ListItem() {
              Column() {
                Text(task.comicTitle)
                  .fontSize(15)
                  .fontColor(SysTheme.FONT_PRIMARY)
                Text(`${task.chapterTitle} — ${task.status} ${task.progress}%`)
                  .fontSize(12)
                  .fontColor(SysTheme.FONT_SECONDARY)
                  .margin({ top: 4 })
                Progress({ value: task.progress, total: 100 })
                  .margin({ top: 8 })
              }
              .padding(12)
              .width('100%')
            }
          }, (t: DownloadTask) => t.id)
        }
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
