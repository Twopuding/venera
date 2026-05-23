import { router } from '@kit.ArkUI';
import { Comic, ExploreSection } from '../../common/models/ComicModels';
import { ComicListRow } from '../../common/components/ComicListRow';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';

/** 单个 explore_pages Tab 内容 — 对齐上游 _SingleExplorePage */
@Component
export struct SingleExplorePanel {
  @Prop @Watch('onTitleChanged') pageTitle: string = '';
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  scroller: Scroller = new Scroller();
  @State sections: ExploreSection[] = [];
  @State flatComics: Comic[] = [];
  @State maxPage: number = 1;
  @State currentPage: number = 1;
  @State loading: boolean = false;
  @State hint: string = '';

  aboutToAppear(): void {
    this.loadContent();
  }

  onTitleChanged(): void {
    this.currentPage = 1;
    this.loadContent();
  }

  onRefreshTick(): void {
    this.currentPage = 1;
    this.loadContent();
  }

  refresh(): void {
    this.currentPage = 1;
    this.loadContent();
  }

  private async loadContent(): Promise<void> {
    if (this.pageTitle.length === 0) {
      return;
    }
    this.loading = true;
    this.hint = '';
    const status = JsEngineBridge.getInstance().getStatus();
    if (!status.runtimeReady) {
      this.hint = status.runtimeNote;
      this.sections = [];
      this.flatComics = [];
      this.loading = false;
      return;
    }
    const result = await ComicSourceService.getInstance().loadExploreByTitle(this.pageTitle, this.currentPage);
    if (!result) {
      this.hint = '未找到该探索页，请刷新漫画源';
      this.sections = [];
      this.flatComics = [];
      this.loading = false;
      return;
    }
    this.sections = result.sections;
    this.flatComics = result.comics;
    this.maxPage = result.maxPage;
    if (this.sections.length === 0 && this.flatComics.length === 0) {
      this.hint = '暂无内容，部分源需登录后查看';
    }
    this.loading = false;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  build() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(48).height(48)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.hint.length > 0 && this.sections.length === 0 && this.flatComics.length === 0) {
      Column() {
        Text(this.hint)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll(this.scroller) {
        Column() {
          if (this.flatComics.length > 0) {
            ForEach(this.flatComics, (comic: Comic) => {
              ComicListRow({
                comic: comic,
                onItemClick: () => this.openComic(comic)
              })
            }, (c: Comic) => `${c.sourceKey}_${c.id}`)
            if (this.maxPage > 1) {
              Row({ space: 12 }) {
                Button('上一页')
                  .enabled(this.currentPage > 1)
                  .onClick(async () => {
                    this.currentPage--;
                    await this.loadContent();
                  })
                Text(`${this.currentPage} / ${this.maxPage}`)
                  .fontSize(13)
                  .fontColor(SysTheme.FONT_SECONDARY)
                Button('下一页')
                  .enabled(this.currentPage < this.maxPage)
                  .onClick(async () => {
                    this.currentPage++;
                    await this.loadContent();
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
            }
          }
          ForEach(this.sections, (section: ExploreSection) => {
            Column() {
              Text(section.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(SysTheme.FONT_PRIMARY)
                .width('100%')
                .padding({ left: 16, top: 12, bottom: 8 })
              ForEach(section.comics, (comic: Comic) => {
                ComicListRow({
                  comic: comic,
                  onItemClick: () => this.openComic(comic)
                })
              }, (c: Comic) => `${c.sourceKey}_${c.id}`)
            }
            .width('100%')
          }, (s: ExploreSection) => s.title)
        }
        .width('100%')
        .padding({ bottom: ShellInsets.FLOATING_BAR_RESERVE })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}
