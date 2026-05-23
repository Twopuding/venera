import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { Comic, AggregatedSearchRow } from '../../common/models/ComicModels';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { AppDataService } from '../../common/services/AppDataService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { TagTranslationService } from '../../common/services/TagTranslationService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 聚合搜索 — 对齐上游 aggregated_search_page.dart，按源分区横向预览 */
@Entry
@Component
struct AggregatedSearchPage {
  @State keyword: string = '';
  @State rows: AggregatedSearchRow[] = [];
  @State searching: boolean = false;
  @State engineHint: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.keyword = params['keyword'] ?? '';
    const status = JsEngineBridge.getInstance().getStatus();
    if (!status.runtimeReady) {
      this.engineHint = status.runtimeNote;
    } else {
      ComicSourceService.getInstance().getAggregatedSearchSourceKeys().then((keys: string[]) => {
        this.engineHint = `聚合 ${keys.length} 个可搜索源`;
      });
    }
    if (this.keyword.trim().length > 0) {
      this.runSearch();
    }
  }

  private async buildRows(): Promise<AggregatedSearchRow[]> {
    const keys = await ComicSourceService.getInstance().getAggregatedSearchSourceKeys();
    const out: AggregatedSearchRow[] = [];
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const src = ComicSourceService.getInstance().getSourceByKey(key);
      const row = new AggregatedSearchRow();
      row.sourceKey = key;
      row.sourceName = src?.name ?? key;
      row.loading = false;
      out.push(row);
    }
    return out;
  }

  private async runSearch(): Promise<void> {
    const word = this.keyword.trim();
    if (word.length === 0) {
      return;
    }
    AppDataService.getInstance().addSearchHistory(word);
    this.searching = true;
    this.rows = await this.buildRows();
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].loading = true;
      this.rows[i].error = '';
      this.rows[i].comics = [];
    }
    this.rows = [...this.rows];
    for (let i = 0; i < this.rows.length; i++) {
      const row = this.rows[i];
      try {
        const comics = await ComicSourceService.getInstance().searchOneSource(row.sourceKey, word);
        row.comics = comics.slice(0, 12);
        row.error = row.comics.length === 0 ? '无结果' : '';
      } catch (e) {
        row.error = `${e}`;
        row.comics = [];
      }
      row.loading = false;
      this.rows = [...this.rows];
    }
    this.searching = false;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  private openSourceSearch(row: AggregatedSearchRow): void {
    router.pushUrl({
      url: 'pages/search/SearchPage',
      params: {
        sourceKey: row.sourceKey,
        sourceName: row.sourceName,
        keyword: this.keyword
      }
    });
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.aggregated_search') })

      Text(this.engineHint)
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, top: 12 })

      Row({ space: 8 }) {
        TextInput({ placeholder: '聚合搜索…', text: this.keyword })
          .layoutWeight(1)
          .onChange((v: string) => { this.keyword = v; })
          .onSubmit(() => this.runSearch())
        Button('搜索')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .enabled(!this.searching)
          .onClick(() => this.runSearch())
      }
      .padding(16)

      if (this.searching && this.rows.length === 0) {
        LoadingProgress().width(48).height(48).margin(24)
      } else if (this.rows.length === 0) {
        Text('暂无可搜索的已缓存漫画源，请先在发现页刷新源')
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.rows, (row: AggregatedSearchRow) => {
            ListItem() {
              Column() {
                Row() {
                  Text(row.sourceName)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(SysTheme.FONT_PRIMARY)
                    .layoutWeight(1)
                  Text('查看全部')
                    .fontSize(12)
                    .fontColor(SysTheme.EMPHASIZE)
                    .onClick(() => this.openSourceSearch(row))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 8 })

                if (row.loading) {
                  LoadingProgress().width(32).height(32).margin({ left: 16, bottom: 12 })
                } else if (row.error.length > 0 && row.comics.length === 0) {
                  Text(row.error)
                    .fontSize(13)
                    .fontColor(SysTheme.FONT_SECONDARY)
                    .padding({ left: 16, right: 16, bottom: 12 })
                } else if (row.comics.length > 0) {
                  Scroll() {
                    Row({ space: 10 }) {
                      ForEach(row.comics, (comic: Comic) => {
                        this.comicTile(comic)
                      }, (c: Comic) => `${c.sourceKey}_${c.id}`)
                    }
                    .padding({ left: 16, right: 16, bottom: 12 })
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }, (row: AggregatedSearchRow) => row.sourceKey)
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
  comicTile(comic: Comic) {
    Column() {
      if (comic.cover.length > 0) {
        Image(ImageCacheUtil.resolveSync(comic.cover))
          .width(90)
          .height(128)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      } else {
        Column()
          .width(90)
          .height(128)
          .borderRadius(8)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      }
      Text(TagTranslationService.translateTagLine(comic.title))
        .fontSize(11)
        .fontColor(SysTheme.FONT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(90)
        .margin({ top: 4 })
    }
    .onClick(() => this.openComic(comic))
  }
}
