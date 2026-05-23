import { STARTUP_SPLASH_MESSAGE_KEY } from '../constants/StartupKeys';
import { SysTheme } from '../theme/SysTheme';

/** 启动引导层（仅 LaunchPage 使用，轻量无 MainShell 依赖） */
@Component
export struct StartupSplash {
  @StorageLink(STARTUP_SPLASH_MESSAGE_KEY) splashMessage: ResourceStr = $r('app.string.startup_initializing');

  build() {
    Column({ space: 20 }) {
      Image($r('app.media.layered_image'))
        .width(96)
        .height(96)
        .objectFit(ImageFit.Contain)

      LoadingProgress()
        .width(40)
        .height(40)
        .color(SysTheme.EMPHASIZE)

      Text(this.splashMessage)
        .fontSize(14)
        .fontColor(SysTheme.FONT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
