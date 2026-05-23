import { router } from '@kit.ArkUI';
import {
  Comic,
  ExploreMixedBlock,
  ExplorePageLoadResult,
  ExploreSection
} from '../../common/models/ComicModels';
import { ComicListRow } from '../../common/components/ComicListRow';
import { ComicGridTile } from '../../common/components/ComicGridTile';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { PageJumpTarget } from '../../common/utils/PageJumpUtil';
import { EXPLORE_SCROLL_TOP_KEY } from '../../common/constants/StartupKeys';
import { BlockedWordsUtil } from '../../common/utils/BlockedWordsUtil';
import { ExploreDisplayUtil } from '../../common/utils/ExploreDisplayUtil';

/** 单个 explore_pages Tab — 对齐 upstream _SingleExplorePage + _MixedExplorePage */
@Component
export struct SingleExplorePanel {
  @Prop @Watch('onTitleChanged') pageTitle: string = '';
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @Prop useGridLayout: boolean = true;
  onScrollOffset?: (offset: number) => void;
  panelScroller: Scroller = new Scroller();
  @State sections: ExploreSection[] = [];
  @State mixedBlocks: ExploreMixedBlock[] = [];
  @State flatComics: Comic[] = [];
  @State maxPage: number = 1;
  @State currentPage: number = 1;
  @State nextCursor: string = '';
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State sourceKey: string = '';
  @StorageLink(EXPLORE_SCROLL_TOP_KEY) @Watch('onScrollTopSignal') scrollTopTick: number = 0;
  private lastScrollY: number = 0;

  aboutToAppear(): void {
    this.loadContent(false);
  }

  onTitleChanged(): void {
    this.currentPage = 1;
    this.nextCursor = '';
    this.loadContent(false);
  }

  onRefreshTick(): void {
    this.currentPage = 1;
    this.nextCursor = '';
    this.loadContent(false);
  }

  onScrollTopSignal(): void {
    this.panelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 200 } });
  }

  scrollToTop(): void {
    this.panelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 200 } });
  }

  refresh(): void {
    this.currentPage = 1;
    this.nextCursor = '';
    this.loadContent(false);
  }

  private async loadContent(append: boolean): Promise<void> {
    if (this.pageTitle.length === 0) {
      return;
    }
    if (append) {
      this.loadingMore = true;
    } else {
      this.loading = true;
      this.error = '';
    }
    const status = JsEngineBridge.getInstance().getStatus();
    if (!status.runtimeReady) {
      this.error = status.runtimeNote;
      this.sections = [];
      this.mixedBlocks = [];
      this.flatComics = [];
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    const result: ExplorePageLoadResult | null = await ComicSourceService.getInstance()
      .loadExploreByTitle(this.pageTitle, this.currentPage, append ? this.nextCursor : '');
    if (!result) {
      this.error = '未找到该探索页，请刷新漫画源';
      this.sections = [];
      this.mixedBlocks = [];
      this.flatComics = [];
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    if (result.error.length > 0) {
      this.error = result.error;
    }
    this.sourceKey = result.sourceKey;
    this.maxPage = result.maxPage > 0 ? result.maxPage : 1;
    if (append && result.comics.length > 0) {
      this.flatComics = [...this.flatComics, ...BlockedWordsUtil.filterComics(result.comics)];
    } else if (!append) {
      this.sections = this.filterSections(result.sections);
      this.mixedBlocks = this.filterMixedBlocks(result.mixedBlocks);
      this.flatComics = BlockedWordsUtil.filterComics(result.comics);
    }
    if (result.nextCursor.length > 0) {
      this.nextCursor = result.nextCursor;
    } else if (!append) {
      this.nextCursor = '';
    }
    if (!append && this.sections.length === 0 && this.mixedBlocks.length === 0 &&
      this.flatComics.length === 0 && this.error.length === 0) {
      this.error = '暂无内容，部分源需登录后查看';
    }
    this.loading = false;
    this.loadingMore = false;
  }

  private filterSections(sections: ExploreSection[]): ExploreSection[] {
    const out: ExploreSection[] = [];
    for (let i = 0; i < sections.length; i++) {
      const s = sections[i];
      const filtered = BlockedWordsUtil.filterComics(s.comics);
      if (filtered.length > 0) {
        const copy = new ExploreSection();
        copy.title = s.title;
        copy.viewMoreJson = s.viewMoreJson;
        copy.comics = filtered;
        out.push(copy);
      }
    }
    return out;
  }

  private filterMixedBlocks(blocks: ExploreMixedBlock[]): ExploreMixedBlock[] {
    const out: ExploreMixedBlock[] = [];
    for (let i = 0; i < blocks.length; i++) {
      const b = blocks[i];
      const filtered = BlockedWordsUtil.filterComics(b.comics);
      if (filtered.length > 0) {
        const copy = new ExploreMixedBlock();
        copy.kind = b.kind;
        copy.title = b.title;
        copy.comics = filtered;
        out.push(copy);
      }
    }
    return out;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  private openViewMore(viewMoreJson: string): void {
    if (viewMoreJson.length === 0 || this.sourceKey.length === 0) {
      return;
    }
    try {
      const raw = JSON.parse(viewMoreJson) as Object;
      PageJumpTarget.jump(PageJumpTarget.parse(this.sourceKey, raw));
    } catch (_e) {
      PageJumpTarget.jump(PageJumpTarget.parse(this.sourceKey, viewMoreJson));
    }
  }

  private onListScroll(x: number, y: number): void {
    if (this.onScrollOffset) {
      this.onScrollOffset(y);
    }
    this.lastScrollY = y;
  }

  private canLoadMoreFlat(): boolean {
    return this.nextCursor.length > 0 || (this.maxPage > 1 && this.currentPage < this.maxPage);
  }

  private async loadMoreFlat(): Promise<void> {
    if (this.loadingMore || this.loading) {
      return;
    }
    if (this.nextCursor.length > 0) {
      await this.loadContent(true);
      return;
    }
    if (this.currentPage < this.maxPage) {
      this.currentPage++;
      await this.loadContent(false);
    }
  }

  build() {
    if (this.loading && !this.loadingMore) {
      Column() {
        LoadingProgress().width(48).height(48)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.error.length > 0 && this.sections.length === 0 && this.mixedBlocks.length === 0 &&
      this.flatComics.length === 0) {
      Column({ space: 12 }) {
        Text(this.error)
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .textAlign(TextAlign.Center)
          .padding(16)
        Button($r('app.string.retry_download'))
          .type(ButtonType.Capsule)
          .onClick(() => this.refresh())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll(this.panelScroller) {
        Column() {
          if (this.mixedBlocks.length > 0) {
            this.buildMixedBlocks()
            if (this.maxPage > 1) {
              Row({ space: 12 }) {
                Button('上一页')
                  .enabled(this.currentPage > 1 && !this.loadingMore)
                  .onClick(async () => {
                    this.currentPage--;
                    await this.loadContent(false);
                  })
                Text(`${this.currentPage} / ${this.maxPage}`)
                  .fontSize(13)
                  .fontColor(SysTheme.FONT_SECONDARY)
                Button('下一页')
                  .enabled(this.currentPage < this.maxPage && !this.loadingMore)
                  .onClick(async () => {
                    this.currentPage++;
                    await this.loadContent(false);
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
            }
          }
          if (this.sections.length > 0) {
            this.buildSections()
          }
          if (this.flatComics.length > 0) {
            this.buildFlatList()
          }
          if (this.loadingMore) {
            LoadingProgress().width(32).height(32).margin(16)
          }
        }
        .width('100%')
        .padding({ bottom: ShellInsets.FLOATING_BAR_RESERVE + 72 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScroll((xOffset: number, yOffset: number) => {
        this.onListScroll(xOffset, yOffset);
      })
      .onReachEnd(() => {
        if (this.canLoadMoreFlat()) {
          this.loadMoreFlat();
        }
      })
    }
  }

  @Builder
  buildSections() {
    ForEach(this.sections, (section: ExploreSection) => {
      Column() {
        this.buildSectionHeader(section.title, section.viewMoreJson)
        this.buildComicGrid(section.comics)
      }
      .width('100%')
      .margin({ bottom: 8 })
    }, (s: ExploreSection) => s.title)
  }

  @Builder
  buildMixedBlocks() {
    ForEach(this.mixedBlocks, (block: ExploreMixedBlock, index: number) => {
      Column() {
        if (block.kind === 'section' && block.title.length > 0) {
          this.buildSectionHeader(block.title, block.viewMoreJson)
        }
        this.buildComicGrid(block.comics)
      }
      .width('100%')
      .margin({ bottom: 8 })
    }, (b: ExploreMixedBlock, index: number) => `mix_${index}_${b.kind}`)
  }

  @Builder
  buildSectionHeader(title: string, viewMoreJson: string) {
    Row() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
      if (viewMoreJson.length > 0) {
        Text($r('app.string.view_more'))
          .fontSize(13)
          .fontColor(SysTheme.EMPHASIZE)
          .onClick(() => this.openViewMore(viewMoreJson))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 10, bottom: 6 })
  }

  @Builder
  buildComicGrid(comics: Comic[]) {
    if (this.useGridLayout) {
      Grid() {
        ForEach(comics, (comic: Comic) => {
          GridItem() {
            ComicGridTile({
              comic: comic,
              tileScale: ExploreDisplayUtil.tileScale(),
              briefMode: ExploreDisplayUtil.isBriefMode(),
              onItemClick: () => this.openComic(comic)
            })
          }
        }, (c: Comic) => `${c.sourceKey}_${c.id}`)
      }
      .columnsTemplate(ExploreDisplayUtil.gridColumnsTemplate())
      .columnsGap(8)
      .rowsGap(10)
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })
    } else {
      Column() {
        ForEach(comics, (comic: Comic) => {
          ComicListRow({
            comic: comic,
            onItemClick: () => this.openComic(comic)
          })
        }, (c: Comic) => `${c.sourceKey}_${c.id}_row`)
      }
    }
  }

  @Builder
  buildFlatList() {
    if (this.useGridLayout) {
      this.buildComicGrid(this.flatComics)
    } else {
      ForEach(this.flatComics, (comic: Comic) => {
        ComicListRow({
          comic: comic,
          onItemClick: () => this.openComic(comic)
        })
      }, (c: Comic) => `${c.sourceKey}_${c.id}`)
    }
    if (this.maxPage > 1 && this.nextCursor.length === 0) {
      Row({ space: 12 }) {
        Button('上一页')
          .enabled(this.currentPage > 1 && !this.loadingMore)
          .onClick(async () => {
            this.currentPage--;
            await this.loadContent(false);
          })
        Text(`${this.currentPage} / ${this.maxPage}`)
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
        Button('下一页')
          .enabled(this.currentPage < this.maxPage && !this.loadingMore)
          .onClick(async () => {
            this.currentPage++;
            await this.loadContent(false);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(16)
    }
  }
}
