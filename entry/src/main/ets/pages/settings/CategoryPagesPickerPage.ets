import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { CategoryPageMeta } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 配置分类 Tab 展示的源 — 对齐 upstream setCategoryPagesWidget */
@Entry
@Component
struct CategoryPagesPickerPage {
  @State available: CategoryPageMeta[] = [];
  @State selected: string[] = [];

  aboutToAppear(): void {
    this.selected = [...AppDataService.getInstance().settings.categoryPages];
    this.loadAvailable();
  }

  private async loadAvailable(): Promise<void> {
    this.available = await ComicSourceService.getInstance().listCategoryPageMeta();
  }

  private isSelected(key: string): boolean {
    return this.selected.indexOf(key) >= 0;
  }

  private toggle(key: string): void {
    const idx = this.selected.indexOf(key);
    if (idx >= 0) {
      this.selected.splice(idx, 1);
    } else {
      this.selected.push(key);
    }
    this.selected = [...this.selected];
  }

  private async save(): Promise<void> {
    AppDataService.getInstance().settings.categoryPages = [...this.selected];
    await AppDataService.getInstance().save();
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.category_pages_settings') })

      Text($r('app.string.category_pages_hint'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.available.length === 0) {
        Text($r('app.string.category_pages_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.available, (meta: CategoryPageMeta) => {
            ListItem() {
              Row() {
                Column() {
                  Text(meta.title)
                    .fontSize(16)
                    .fontColor(SysTheme.FONT_PRIMARY)
                  Text(meta.key)
                    .fontSize(11)
                    .fontColor(SysTheme.FONT_SECONDARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isSelected(meta.key) })
                  .onChange(() => this.toggle(meta.key))
              }
              .width('100%')
              .padding(16)
            }
          }, (meta: CategoryPageMeta) => meta.key)
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
