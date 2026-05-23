import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { CategoryItem, ComicSourceInfo, RankingPageInfo } from '../../common/models/ComicModels';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { ENGINE_READY_KEY } from '../../common/constants/StartupKeys';

/** 分类 — 对应 upstream lib/pages/categories_page.dart */
@Component
export struct CategoriesPage {
  scroller: Scroller = new Scroller();
  @Prop @Watch('onInitialSourceChanged') initialSourceKey: string = '';
  @State categories: CategoryItem[] = [];
  @State sources: ComicSourceInfo[] = [];
  @State selectedSource: string = '';
  @State loading: boolean = false;
  @State rankingPages: RankingPageInfo[] = [];
  @StorageLink(ENGINE_READY_KEY) @Watch('onEngineReadyChanged') engineReady: boolean = false;

  aboutToAppear(): void {
    this.sources = ComicSourceService.getInstance().getSources();
    this.consumePendingSource();
    this.applyInitialSource();
    this.tryLoadRankingPages();
  }

  onPageShow(): void {
    this.sources = ComicSourceService.getInstance().getSources();
    this.consumePendingSource();
    this.applyInitialSource();
    this.tryLoadRankingPages();
  }

  onEngineReadyChanged(): void {
    this.sources = ComicSourceService.getInstance().getSources();
    this.applyInitialSource();
    this.tryLoadRankingPages();
  }

  private consumePendingSource(): void {
    const pending = AppDataService.getInstance().pendingCategorySourceKey;
    if (pending.length > 0) {
      AppDataService.getInstance().pendingCategorySourceKey = '';
      this.selectedSource = pending;
      this.loadCategories();
    }
  }

  private tryLoadRankingPages(): void {
    if (!this.engineReady) {
      return;
    }
    this.loadRankingPages();
  }

  private async loadRankingPages(): Promise<void> {
    this.rankingPages = await ComicSourceService.getInstance().listRankingPages();
  }

  onInitialSourceChanged(): void {
    this.applyInitialSource();
  }

  private applyInitialSource(): void {
    if (this.sources.length === 0) {
      return;
    }
    if (this.initialSourceKey.length > 0 &&
      this.sources.some((s: ComicSourceInfo) => s.key === this.initialSourceKey)) {
      if (this.selectedSource !== this.initialSourceKey) {
        this.selectedSource = this.initialSourceKey;
        this.loadCategories();
      }
      return;
    }
    if (this.selectedSource.length === 0) {
      this.selectedSource = this.sources[0].key;
      this.loadCategories();
    }
  }

  async loadCategories(): Promise<void> {
    if (this.selectedSource.length === 0) {
      this.categories = [];
      return;
    }
    this.loading = true;
    this.categories = await ComicSourceService.getInstance().getCategories(this.selectedSource);
    this.loading = false;
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        if (this.sources.length > 1) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.sources, (src: ComicSourceInfo) => {
                Button(src.name)
                  .type(ButtonType.Capsule)
                  .height(32)
                  .backgroundColor(this.selectedSource === src.key ?
                    SysTheme.EMPHASIZE : SysTheme.BACKGROUND_SECONDARY)
                  .onClick(() => {
                    this.selectedSource = src.key;
                    this.loadCategories();
                  })
              }, (src: ComicSourceInfo) => src.key)
            }
            .padding({ left: 16, right: 16, bottom: 8 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }

        if (!JsEngineBridge.getInstance().isReady()) {
          Text($r('app.string.js_engine_not_ready'))
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, right: 16, bottom: 8 })
        }

        if (this.rankingPages.length > 0) {
          Text($r('app.string.ranking_section'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, top: 4, bottom: 8 })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.rankingPages, (rp: RankingPageInfo) => {
                Button(rp.categoryTitle.length > 0 ? rp.categoryTitle : rp.sourceKey)
                  .type(ButtonType.Capsule)
                  .height(32)
                  .onClick(() => router.pushUrl({
                    url: 'pages/ranking/RankingPage',
                    params: { sourceKey: rp.sourceKey, title: rp.categoryTitle }
                  }))
              }, (rp: RankingPageInfo) => rp.sourceKey)
            }
            .padding({ left: 16, right: 16, bottom: 8 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }

        if (this.loading) {
          LoadingProgress().width(36).height(36).margin(16)
        } else if (this.categories.length === 0) {
          Text($r('app.string.categories_hint'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, right: 16, top: 8 })
        } else {
          List() {
            ForEach(this.categories, (cat: CategoryItem) => {
              ListItem() {
                Column() {
                  Text(cat.label)
                    .fontSize(15)
                    .fontColor(SysTheme.FONT_PRIMARY)
                  if (cat.partName.length > 0) {
                    Text(cat.partName)
                      .fontSize(12)
                      .fontColor(SysTheme.FONT_SECONDARY)
                      .margin({ top: 4 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .padding(16)
                .width('100%')
                .onClick(() => router.pushUrl({
                  url: 'pages/categories/CategoryComicsPage',
                  params: {
                    sourceKey: this.selectedSource,
                    categoryJson: JSON.stringify(cat)
                  }
                }))
              }
            }, (cat: CategoryItem) => `${cat.partName}_${cat.label}_${cat.param}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({
        top: 8,
        bottom: ShellInsets.FLOATING_BAR_RESERVE
      })
    }
    .clipContent(ContentClipMode.SAFE_AREA)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
