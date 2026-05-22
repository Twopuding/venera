import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicSourceInfo } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';

@Entry
@Component
struct ComicSourcePage {
  @State sources: ComicSourceInfo[] = [];

  aboutToAppear(): void {
    this.sources = ComicSourceService.getInstance().getSources();
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.comic_sources'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(SysTheme.FONT_PRIMARY)
          .layoutWeight(1)
        Button('刷新')
          .onClick(async () => {
            await ComicSourceService.getInstance().refreshIndex();
            this.sources = ComicSourceService.getInstance().getSources();
          })
      }
      .padding(16)

      Text(JsEngineBridge.getInstance().getStatus().runtimeNote)
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 8 })

      List() {
        ForEach(this.sources, (src: ComicSourceInfo) => {
          ListItem() {
            Column() {
              Text(src.name)
                .fontSize(16)
                .fontColor(SysTheme.FONT_PRIMARY)
              Row() {
                Text(`${src.key} v${src.version}`)
                  .fontSize(12)
                  .fontColor(SysTheme.FONT_SECONDARY)
                if (ComicSourceService.getInstance().isSourceCached(src.key)) {
                  Text(' · 已缓存')
                    .fontSize(12)
                    .fontColor(SysTheme.EMPHASIZE)
                }
              }
              .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .width('100%')
          }
        }, (src: ComicSourceInfo) => src.key)
      }
      .layoutWeight(1)

      Button('返回')
        .margin(16)
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
