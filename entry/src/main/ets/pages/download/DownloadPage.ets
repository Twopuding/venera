import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { DownloadService } from '../../common/services/DownloadService';
import { DownloadTask } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

@Entry
@Component
struct DownloadPage {
  @State tasks: DownloadTask[] = [];

  aboutToAppear(): void {
    this.refresh();
    DownloadService.getInstance().onChange(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    this.tasks = DownloadService.getInstance().getTasks();
  }

  private statusLabel(task: DownloadTask): string {
    switch (task.status) {
      case 'pending':
        return '等待中';
      case 'downloading':
        return '下载中';
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      default:
        return task.status;
    }
  }

  build() {
    Column() {
        SecondaryPageHeader({
        title: $r('app.string.downloads'),
        trailing: () => {
          if (this.tasks.some((t: DownloadTask) => t.status === 'completed')) {
            Button($r('app.string.clear_completed_downloads'))
              .type(ButtonType.Capsule)
              .height(32)
              .fontSize(12)
              .onClick(async () => {
                await DownloadService.getInstance().clearCompleted();
                try {
                  promptAction.showToast({ message: '已清除已完成任务', duration: 2000 });
                } catch (_e) {
                  console.info('[DownloadPage] cleared completed');
                }
              })
          }
        }
      })

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
                Text(`${task.chapterTitle} — ${this.statusLabel(task)} ${task.progress}%`)
                  .fontSize(12)
                  .fontColor(SysTheme.FONT_SECONDARY)
                  .margin({ top: 4 })
                if (task.status === 'downloading' || task.status === 'pending') {
                  Progress({ value: task.progress, total: 100 })
                    .margin({ top: 8 })
                }
                Row({ space: 8 }) {
                  if (task.status === 'failed') {
                    Button($r('app.string.retry_download'))
                      .type(ButtonType.Capsule)
                      .height(28)
                      .fontSize(12)
                      .onClick(async () => {
                        await DownloadService.getInstance().retryTask(task.id);
                      })
                  }
                  if (task.status !== 'downloading') {
                    Button($r('app.string.remove_download'))
                      .type(ButtonType.Capsule)
                      .height(28)
                      .fontSize(12)
                      .onClick(async () => {
                        await DownloadService.getInstance().removeTask(task.id);
                      })
                  }
                }
                .margin({ top: 8 })
              }
              .padding(12)
              .width('100%')
            }
          }, (t: DownloadTask) => t.id)
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
