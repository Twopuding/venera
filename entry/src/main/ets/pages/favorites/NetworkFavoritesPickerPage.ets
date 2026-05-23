import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { NetworkFavoriteMeta } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 配置收藏 Tab 展示的网络收藏源 — 对齐 upstream setFavoritesPagesWidget */
@Entry
@Component
struct NetworkFavoritesPickerPage {
  @State available: NetworkFavoriteMeta[] = [];
  @State selected: string[] = [];

  aboutToAppear(): void {
    this.selected = [...AppDataService.getInstance().settings.networkFavorites];
    this.loadAvailable();
  }

  private async loadAvailable(): Promise<void> {
    await ComicSourceService.getInstance().ensureEngineReady();
    const keys = await JsEngineBridge.getInstance().invokeListFavoriteSourceKeys();
    const metas: NetworkFavoriteMeta[] = [];
    for (let i = 0; i < keys.length; i++) {
      const meta = await ComicSourceService.getInstance().getNetworkFavoriteMeta(keys[i]);
      if (meta) {
        metas.push(meta);
      }
    }
    this.available = metas;
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
    AppDataService.getInstance().settings.networkFavorites = [...this.selected];
    await AppDataService.getInstance().save();
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.network_favorites_settings') })

      Text($r('app.string.network_favorites_settings_hint'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.available.length === 0) {
        Text($r('app.string.network_favorites_settings_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.available, (meta: NetworkFavoriteMeta) => {
            ListItem() {
              Row() {
                Text(meta.title)
                  .fontSize(16)
                  .fontColor(SysTheme.FONT_PRIMARY)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isSelected(meta.sourceKey) })
                  .onChange(() => this.toggle(meta.sourceKey))
              }
              .width('100%')
              .padding(16)
            }
          }, (meta: NetworkFavoriteMeta) => meta.sourceKey)
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
