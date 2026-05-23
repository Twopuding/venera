import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { CategoryComicsResult, CategoryItem, Comic } from '../../common/models/ComicModels';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 分类漫画列表 — 对应上游 categoryComics.load */
@Entry
@Component
struct CategoryComicsPage {
  @State sourceKey: string = '';
  @State categoryItem: CategoryItem = new CategoryItem();
  @State comics: Comic[] = [];
  @State page: number = 1;
  @State maxPage: number = 1;
  @State loading: boolean = false;
  @State engineHint: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    if (params['categoryJson']) {
      this.categoryItem = JSON.parse(params['categoryJson']) as CategoryItem;
    }
    const status = JsEngineBridge.getInstance().getStatus();
    this.engineHint = status.runtimeReady ? '' : status.runtimeNote;
    this.loadPage(1, false);
  }

  private async loadPage(targetPage: number, append: boolean): Promise<void> {
    if (this.sourceKey.length === 0 || this.categoryItem.label.length === 0) {
      return;
    }
    this.loading = true;
    const result: CategoryComicsResult = await ComicSourceService.getInstance()
      .loadCategoryComics(this.sourceKey, this.categoryItem, targetPage);
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
      SecondaryPageHeader({ title: this.categoryItem.label })

      if (this.categoryItem.partName.length > 0) {
        Text(this.categoryItem.partName)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 4 })
      }

      if (this.engineHint.length > 0) {
        Text(this.engineHint)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.loading && this.comics.length === 0) {
        LoadingProgress().width(48).height(48).margin(24)
      } else if (this.comics.length === 0 && !this.loading) {
        Text($r('app.string.category_comics_empty'))
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
