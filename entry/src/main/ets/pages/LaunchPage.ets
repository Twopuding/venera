import { STARTUP_SPLASH_MESSAGE_KEY } from '../common/constants/StartupKeys';

/**
 * 启动轻页：本文件不得 import 任何 Service / JsEngine / MainShell。
 */
@Entry
@Component
struct LaunchPage {
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
        .color($r('app.color.accent'))

      Text(this.splashMessage)
        .fontSize(14)
        .fontColor($r('app.color.secondary_text'))
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.card_background'))
  }
}
