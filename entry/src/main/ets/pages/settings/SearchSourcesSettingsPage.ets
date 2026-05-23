import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 聚合搜索参与源勾选 — 对齐上游 searchSources 设置 */
@Entry
@Component
struct SearchSourcesSettingsPage {
  @State sourceKeys: string[] = [];

  aboutToAppear(): void {
    ComicSourceService.getInstance().getSearchableSourceKeysForSettings().then((keys: string[]) => {
      this.sourceKeys = keys;
    });
  }

  private isEnabled(key: string): boolean {
    return ComicSourceService.getInstance().isSourceInAggregatedSearch(key);
  }

  build() {
    Column() {
        SecondaryPageHeader({ title: $r('app.string.search_sources_settings') })

      Text($r('app.string.search_sources_hint'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.sourceKeys.length === 0) {
        Text($r('app.string.search_sources_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.sourceKeys, (key: string) => {
            ListItem() {
              Row() {
                Column() {
                  Text(ComicSourceService.getInstance().getSourceByKey(key)?.name ?? key)
                    .fontSize(16)
                    .fontColor(SysTheme.FONT_PRIMARY)
                  Text(key)
                    .fontSize(11)
                    .fontColor(SysTheme.FONT_SECONDARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isEnabled(key) })
                  .onChange((on: boolean) => {
                    ComicSourceService.getInstance().toggleAggregatedSearchSource(key, on).then(() => {
                      this.sourceKeys = [...this.sourceKeys];
                    });
                  })
              }
              .width('100%')
              .padding(16)
            }
          }, (key: string) => key)
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
