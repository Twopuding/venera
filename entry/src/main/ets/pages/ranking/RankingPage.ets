import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { CategoryComicsResult, Comic } from '../../common/models/ComicModels';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 漫画源排行榜 — 对齐上游 ranking_page.dart（categoryComics.ranking.load） */
@Entry
@Component
struct RankingPage {
  @State sourceKey: string = '';
  @State pageTitle: string = '排行榜';
  @State options: string[] = [];
  @State selectedOption: string = '';
  @State comics: Comic[] = [];
  @State page: number = 1;
  @State maxPage: number = 1;
  @State loading: boolean = false;
  @State engineHint: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.pageTitle = params['title'] ?? '排行榜';
    const status = JsEngineBridge.getInstance().getStatus();
    this.engineHint = status.runtimeReady ? '' : status.runtimeNote;
    this.initOptions();
  }

  private async initOptions(): Promise<void> {
    const pages = await ComicSourceService.getInstance().listRankingPages();
    for (let i = 0; i < pages.length; i++) {
      if (pages[i].sourceKey === this.sourceKey) {
        this.options = pages[i].options;
        if (this.options.length > 0) {
          this.selectedOption = this.options[0];
          this.loadPage(1, false);
        }
        return;
      }
    }
  }

  private optionLabel(option: string): string {
    const dash = option.indexOf('-');
    if (dash > 0 && dash < option.length - 1) {
      return option.substring(dash + 1);
    }
    return option;
  }

  private async loadPage(targetPage: number, append: boolean): Promise<void> {
    if (this.sourceKey.length === 0 || this.selectedOption.length === 0) {
      return;
    }
    this.loading = true;
    const result: CategoryComicsResult = await ComicSourceService.getInstance()
      .loadRankingComics(this.sourceKey, this.selectedOption, targetPage);
    this.maxPage = result.maxPage > 0 ? result.maxPage : 1;
    this.page = targetPage;
    this.comics = append ? this.comics.concat(result.comics) : result.comics;
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
      SecondaryPageHeader({ title: this.pageTitle })

      if (this.engineHint.length > 0) {
        Text(this.engineHint)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.options.length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.options, (opt: string) => {
              Button(this.optionLabel(opt))
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .backgroundColor(this.selectedOption === opt ?
                  SysTheme.EMPHASIZE : SysTheme.BACKGROUND_SECONDARY)
                .onClick(() => {
                  if (this.selectedOption !== opt) {
                    this.selectedOption = opt;
                    this.loadPage(1, false);
                  }
                })
            }, (opt: string) => opt)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }

      if (this.loading && this.comics.length === 0) {
        LoadingProgress().width(48).height(48).margin(24)
      } else if (this.comics.length === 0 && !this.loading) {
        Text($r('app.string.ranking_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.comics, (comic: Comic) => {
            ListItem() {
              ComicListRow({
                comic: comic,
                onItemClick: () => this.openComic(comic)
              })
            }
          }, (c: Comic) => `${c.sourceKey}_${c.id}`)
        }
        .layoutWeight(1)

        if (this.page < this.maxPage) {
          Button(this.loading ? '加载中…' : `加载更多 (${this.page}/${this.maxPage})`)
            .margin(16)
            .enabled(!this.loading)
            .onClick(() => this.loadPage(this.page + 1, true))
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
