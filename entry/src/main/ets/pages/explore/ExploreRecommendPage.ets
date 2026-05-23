import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { Comic, ExploreSection } from '../../common/models/ComicModels';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 漫画源 explore 推荐页 — 对应上游 explore_page 分区展示 */
@Entry
@Component
struct ExploreRecommendPage {
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State sections: ExploreSection[] = [];
  @State loading: boolean = false;
  @State hint: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? '';
    this.loadExplore();
  }

  private async loadExplore(): Promise<void> {
    if (this.sourceKey.length === 0) {
      return;
    }
    this.loading = true;
    const status = JsEngineBridge.getInstance().getStatus();
    if (!status.runtimeReady) {
      this.hint = status.runtimeNote;
      this.loading = false;
      return;
    }
    if (!ComicSourceService.getInstance().isSourceCached(this.sourceKey)) {
      this.hint = '请先刷新并缓存该漫画源脚本';
      this.loading = false;
      return;
    }
    this.sections = await ComicSourceService.getInstance().loadExplore(this.sourceKey);
    this.hint = this.sections.length > 0 ? '' : '该源未提供 explore 推荐或需登录后查看';
    this.loading = false;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.sourceName.length > 0 ? `${this.sourceName} · 推荐` : '源推荐'
      })

      if (this.loading) {
        LoadingProgress().width(48).height(48).margin(24)
      } else if (this.hint.length > 0 && this.sections.length === 0) {
        Text(this.hint)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.sections, (section: ExploreSection) => {
            ListItemGroup({ header: this.sectionHeader(section.title) }) {
              ForEach(section.comics, (comic: Comic) => {
                ListItem() {
                  ComicListRow({
                    comic: comic,
                    onItemClick: () => this.openComic(comic)
                  })
                }
              }, (c: Comic) => `${c.sourceKey}_${c.id}`)
            }
          }, (s: ExploreSection) => s.title)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(SysTheme.FONT_PRIMARY)
      .padding({ left: 16, top: 12, bottom: 8 })
  }
}
