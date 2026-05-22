import { router } from '@kit.ArkUI';
import { LocalComicService } from '../../common/services/LocalComicService';
import { SysTheme } from '../../common/theme/SysTheme';

@Entry
@Component
struct LocalLibraryPage {
  @State rootPath: string = '';
  @State importing: boolean = false;
  @State statusMessage: string = '';

  aboutToAppear(): void {
    this.rootPath = LocalComicService.getInstance().getRootPath();
  }

  build() {
    Column() {
      Text($r('app.string.local_library'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)
      Text(`存储路径: ${this.rootPath}`)
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16 })
      Text($r('app.string.import_hint'))
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding(16)
        .layoutWeight(1)

      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.importing) {
        LoadingProgress().width(40).height(40).margin(8)
      }

      Button($r('app.string.import_folder'))
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .margin({ left: 16, right: 16, bottom: 8 })
        .enabled(!this.importing)
        .onClick(async () => {
          this.importing = true;
          this.statusMessage = '';
          const ok = await LocalComicService.getInstance().importFromPicker();
          this.importing = false;
          this.statusMessage = ok ? '导入完成' : '未选择文件或导入失败';
          if (ok) {
            router.back();
          }
        })

      Button($r('app.string.scan_library'))
        .margin({ left: 16, right: 16, bottom: 8 })
        .enabled(!this.importing)
        .onClick(async () => {
          await LocalComicService.getInstance().scanLibrary();
          this.statusMessage = '书架已刷新';
          router.back();
        })

      Button('返回')
        .margin({ left: 16, right: 16, bottom: 16 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
