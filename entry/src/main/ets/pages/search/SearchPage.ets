import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { AppDataService } from '../../common/services/AppDataService';
import { Comic } from '../../common/models/ComicModels';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State results: Comic[] = [];
  @State searching: boolean = false;
  @State history: string[] = AppDataService.getInstance().searchHistory;
  @State engineHint: string = '';
  @State sourceKey: string = '';
  @State sourceName: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? '';
    const kw = params['keyword'] ?? '';
    if (kw.length > 0) {
      this.keyword = kw;
    }
    const status = JsEngineBridge.getInstance().getStatus();
    const scope = this.sourceName.length > 0 ? `源「${this.sourceName}」` : '全部源';
    this.engineHint = status.runtimeReady ?
      `${scope} · 已缓存 ${status.stagedSourceCount} 个源脚本` :
      `${scope} · ${status.runtimeNote}（已缓存 ${status.stagedSourceCount} 个源）`;
  }

  async doSearch(): Promise<void> {
    if (this.keyword.trim().length === 0) {
      return;
    }
    this.searching = true;
    AppDataService.getInstance().addSearchHistory(this.keyword.trim());
    this.history = AppDataService.getInstance().searchHistory;
    const key = this.sourceKey.length > 0 ? this.sourceKey : undefined;
    this.results = await ComicSourceService.getInstance().search(this.keyword.trim(), key);
    this.searching = false;
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
        title: this.sourceName.length > 0 ? this.sourceName : $r('app.string.search')
      })

      Text(this.engineHint)
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, right: 16, top: 12 })

      if (this.sourceName.length > 0) {
        Text(`在 ${this.sourceName} 中搜索`)
          .fontSize(14)
          .fontColor(SysTheme.EMPHASIZE)
          .padding({ left: 16, right: 16 })
      }

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索漫画…', text: this.keyword })
          .layoutWeight(1)
          .onChange((v: string) => { this.keyword = v; })
          .onSubmit(() => this.doSearch())
        Button('搜索')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .onClick(() => this.doSearch())
      }
      .padding({ left: 16, right: 16, top: 0, bottom: 8 })

      if (this.sourceKey.length === 0) {
        Button($r('app.string.aggregated_search'))
          .type(ButtonType.Capsule)
          .height(32)
          .margin({ left: 16, right: 16, bottom: 8 })
          .onClick(() => router.pushUrl({
            url: 'pages/search/AggregatedSearchPage',
            params: { keyword: this.keyword.trim() }
          }))
      }

      if (this.searching) {
        LoadingProgress().width(48).height(48).margin(24)
      } else if (this.results.length > 0) {
        List() {
          ForEach(this.results, (comic: Comic) => {
            ListItem() {
              ComicListRow({
                comic: comic,
                onItemClick: () => this.openComic(comic)
              })
            }
          }, (c: Comic) => `${c.sourceKey}_${c.id}`)
        }
        .layoutWeight(1)
      } else if (this.keyword.length > 0 && !this.searching) {
        Text($r('app.string.search_no_results'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else if (this.history.length > 0) {
        Text('搜索历史')
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, bottom: 8 })
        List() {
          ForEach(this.history, (h: string) => {
            ListItem() {
              Text(h)
                .padding(12)
                .onClick(() => {
                  this.keyword = h;
                  this.doSearch();
                })
            }
          }, (h: string) => h)
        }
        .layoutWeight(1)
      } else {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
