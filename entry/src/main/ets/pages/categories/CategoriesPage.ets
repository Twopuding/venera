import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicSourceInfo } from '../../common/models/ComicModels';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';

/** 分类 — 对应 upstream lib/pages/categories_page.dart */
@Component
export struct CategoriesPage {
  scroller: Scroller = new Scroller();
  @State categories: string[] = [];
  @State sources: ComicSourceInfo[] = [];
  @State selectedSource: string = '';
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.sources = ComicSourceService.getInstance().getSources();
    if (this.sources.length > 0) {
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

        if (this.loading) {
          LoadingProgress().width(36).height(36).margin(16)
        } else if (this.categories.length === 0) {
          Text($r('app.string.categories_hint'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, right: 16, top: 8 })
        } else {
          List() {
            ForEach(this.categories, (cat: string) => {
              ListItem() {
                Text(cat)
                  .fontSize(15)
                  .fontColor(SysTheme.FONT_PRIMARY)
                  .padding(16)
              }
            }, (cat: string) => cat)
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
