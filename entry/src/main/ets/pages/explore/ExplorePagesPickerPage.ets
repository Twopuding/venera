import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 配置发现 Tab 展示的 explore_pages */
@Entry
@Component
struct ExplorePagesPickerPage {
  @State available: string[] = [];
  @State selected: string[] = [];

  aboutToAppear(): void {
    ComicSourceService.getInstance().listExplorePageTitles().then((titles: string[]) => {
      this.available = titles;
    });
    this.selected = [...AppDataService.getInstance().settings.explorePages];
  }

  private isSelected(title: string): boolean {
    return this.selected.indexOf(title) >= 0;
  }

  private toggle(title: string): void {
    const idx = this.selected.indexOf(title);
    if (idx >= 0) {
      this.selected.splice(idx, 1);
    } else {
      this.selected.push(title);
    }
    this.selected = [...this.selected];
  }

  private async save(): Promise<void> {
    AppDataService.getInstance().settings.explorePages = [...this.selected];
    await AppDataService.getInstance().save();
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.explore_pages_settings') })

      Text($r('app.string.explore_pages_hint'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.available.length === 0) {
        Text($r('app.string.explore_pages_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.available, (title: string) => {
            ListItem() {
              Row() {
                Text(title)
                  .fontSize(16)
                  .fontColor(SysTheme.FONT_PRIMARY)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isSelected(title) })
                  .onChange(() => this.toggle(title))
              }
              .width('100%')
              .padding(16)
            }
          }, (title: string) => title)
        }
        .layoutWeight(1)
      }

      Row({ space: 12 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .onClick(() => router.back())
        Button($r('app.string.save'))
          .layoutWeight(1)
          .onClick(() => this.save())
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
