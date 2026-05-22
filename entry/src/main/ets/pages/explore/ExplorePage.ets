import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ComicSourceInfo } from '../../common/models/ComicModels';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';

/** 发现 — 对应 upstream lib/pages/explore_page.dart */
@Component
export struct ExplorePage {
  scroller: Scroller = new Scroller();
  @State sources: ComicSourceInfo[] = [];
  @State refreshing: boolean = false;
  @State cachedCount: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.sources = ComicSourceService.getInstance().getSources();
    this.cachedCount = ComicSourceService.getInstance().getCachedScriptCount();
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        Row({ space: 8 }) {
          Text($r('app.string.explore_sources_count'))
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .layoutWeight(1)
          if (this.refreshing) {
            LoadingProgress().width(20).height(20)
          } else {
            Button($r('app.string.refresh_sources'))
              .type(ButtonType.Capsule)
              .height(32)
              .onClick(async () => {
                this.refreshing = true;
                await ComicSourceService.getInstance().refreshIndex();
                this.reload();
                this.refreshing = false;
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })

        if (this.sources.length === 0) {
          Text($r('app.string.explore_loading'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
        } else {
          List() {
            ForEach(this.sources, (src: ComicSourceInfo) => {
              ListItem() {
                Column() {
                  Row() {
                    Text(src.name)
                      .fontSize(16)
                      .fontColor(SysTheme.FONT_PRIMARY)
                      .layoutWeight(1)
                    if (ComicSourceService.getInstance().isSourceCached(src.key)) {
                      Text($r('app.string.source_cached'))
                        .fontSize(11)
                        .fontColor(SysTheme.EMPHASIZE)
                    }
                  }
                  .width('100%')
                  Text(src.description)
                    .fontSize(12)
                    .fontColor(SysTheme.FONT_SECONDARY)
                    .maxLines(2)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .padding(16)
                .width('100%')
                .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
                .borderRadius(12)
                .margin({ left: 16, right: 16, bottom: 8 })
                .onClick(() => router.pushUrl({
                  url: 'pages/search/SearchPage',
                  params: { sourceKey: src.key, sourceName: src.name }
                }))
              }
            }, (src: ComicSourceInfo) => src.key)
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
