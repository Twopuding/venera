import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { AppConstants } from '../../common/constants/AppConstants';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { SysTheme } from '../../common/theme/SysTheme';

@Entry
@Component
struct SettingsPage {
  @State readerMode: string = AppDataService.getInstance().settings.readerMode;
  @State enableTranslation: boolean = AppDataService.getInstance().settings.enableTranslation;
  @State jsStatus: string = '';

  aboutToAppear(): void {
    const s = JsEngineBridge.getInstance().getStatus();
    this.jsStatus = `init.js ${s.initScriptLength} 字符 · 已暂存 ${s.stagedSourceCount} 源 · ${s.runtimeNote}`;
  }

  build() {
    Column() {
      Text($r('app.string.settings'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)

      List() {
        ListItem() {
          Row() {
            Text('阅读模式')
            Blank()
            Text(this.readerMode)
          }
          .width('100%')
          .padding(16)
          .onClick(() => {
            this.readerMode = this.readerMode === 'vertical' ? 'horizontal' : 'vertical';
            AppDataService.getInstance().settings.readerMode = this.readerMode;
            AppDataService.getInstance().save();
          })
        }
        ListItem() {
          Row() {
            Text('标签翻译')
            Toggle({ type: ToggleType.Switch, isOn: this.enableTranslation })
              .onChange((on: boolean) => {
                this.enableTranslation = on;
                AppDataService.getInstance().settings.enableTranslation = on;
                AppDataService.getInstance().save();
              })
          }
          .width('100%')
          .padding(16)
        }
        ListItem() {
          Text(`上游版本 ${AppConstants.UPSTREAM_VERSION}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
        ListItem() {
          Text(`鸿蒙版本 ${AppConstants.HARMONY_VERSION}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
        ListItem() {
          Text(this.jsStatus)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
      }
      .layoutWeight(1)

      Text($r('app.string.about_title'))
        .fontSize(16)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding({ left: 16, top: 8 })
      Text($r('app.string.port_from'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding(16)

      Button('返回')
        .margin(16)
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
