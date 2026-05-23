import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { AppDataService } from '../../common/services/AppDataService';
import { Comic, SearchOptionDef, SearchPageSourceItem } from '../../common/models/ComicModels';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { SearchUtil } from '../../common/utils/SearchUtil';
import { TagSuggestion, TagTranslationService } from '../../common/services/TagTranslationService';

interface SearchOptionSelectItem {
  value: string;
}

/**
 * 单源搜索结果 — 对齐 upstream search_result_page.dart（分页、顶栏搜索、设置对话框）
 */
@Entry
@Component
struct SearchResultPage {
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State keyword: string = '';
  @State comics: Comic[] = [];
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State currentPage: number = 1;
  @State maxPage: number = 1;
  @State showSettings: boolean = false;
  @State allSearchSources: SearchPageSourceItem[] = [];
  @State dialogOptions: SearchOptionDef[] = [];
  @State dialogOptionValues: string[] = [];
  @State dialogSourceKey: string = '';
  @State suggestions: TagSuggestion[] = [];
  @State tagSuggestionsEnabled: boolean = false;
  private searchOptions: string[] = [];
  private listVersion: number = 0;
  private suggestionRequestId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? this.sourceKey;
    this.keyword = params['keyword'] ?? '';
    const optJson = params['options'] ?? '[]';
    try {
      const parsed = JSON.parse(optJson) as string[];
      if (Array.isArray(parsed)) {
        this.searchOptions = parsed;
      }
    } catch (_e) {
      this.searchOptions = [];
    }
    this.keyword = SearchUtil.checkAutoLanguage(this.keyword.trim(), this.sourceKey);
    this.validateOptionsAsync();
    ComicSourceService.getInstance().isSourceTagSuggestionsEnabled(this.sourceKey)
      .then((enabled: boolean) => {
        this.tagSuggestionsEnabled = enabled;
      });
    if (this.keyword.length > 0) {
      AppDataService.getInstance().addSearchHistory(this.keyword);
      this.loadPage(1, true);
    } else {
      this.loading = false;
    }
  }

  private async validateOptionsAsync(): Promise<void> {
    const defs = await ComicSourceService.getInstance().getSourceSearchOptions(this.sourceKey);
    if (defs.length !== this.searchOptions.length) {
      const values: string[] = [];
      for (let i = 0; i < defs.length; i++) {
        values.push(defs[i].defaultValue);
      }
      this.searchOptions = values;
    }
  }

  private onKeywordChange(v: string): void {
    this.keyword = v;
    this.refreshSuggestionsAsync();
  }

  private refreshSuggestionsAsync(): void {
    if (!this.tagSuggestionsEnabled) {
      this.suggestions = [];
      return;
    }
    const req = ++this.suggestionRequestId;
    const token = SearchUtil.getLastToken(this.keyword);
    if (token.length === 0) {
      this.suggestions = [];
      return;
    }
    const found = TagTranslationService.findTagSuggestions(token, 200);
    if (req === this.suggestionRequestId) {
      this.suggestions = found;
    }
  }

  private async applyTagSuggestion(item: TagSuggestion): Promise<void> {
    let base = SearchUtil.removeTrailingToken(this.keyword, item.tag);
    if (base.length > 0 && !base.endsWith(' ')) {
      base += ' ';
    }
    const insert = await ComicSourceService.getInstance()
      .formatTagSuggestionInsert(this.sourceKey, item.namespace, item.tag);
    this.keyword = base + insert;
    this.suggestions = [];
  }

  private async loadPage(page: number, replace: boolean): Promise<void> {
    if (page > 1) {
      this.loadingMore = true;
    } else {
      this.loading = true;
      this.error = '';
    }
    try {
      const result = await ComicSourceService.getInstance()
        .searchWithOptions(this.sourceKey, this.keyword.trim(), this.searchOptions, page);
      if (replace) {
        this.comics = result.comics;
        this.listVersion++;
      } else {
        this.comics = [...this.comics, ...result.comics];
      }
      this.currentPage = page;
      this.maxPage = result.maxPage > 0 ? result.maxPage : 1;
    } catch (e) {
      this.error = `${e}`;
      if (replace) {
        this.comics = [];
      }
    }
    this.loading = false;
    this.loadingMore = false;
  }

  private canLoadMore(): boolean {
    return !this.loading && !this.loadingMore && this.currentPage < this.maxPage;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  private rerunSearch(): void {
    const word = SearchUtil.checkAutoLanguage(this.keyword.trim(), this.sourceKey);
    this.keyword = word;
    if (word.length === 0) {
      return;
    }
    AppDataService.getInstance().addSearchHistory(word);
    this.loadPage(1, true);
  }

  private async openSettingsDialog(): Promise<void> {
    await ComicSourceService.getInstance().ensureEngineReady();
    this.allSearchSources = await ComicSourceService.getInstance().getSearchPageSources();
    this.dialogSourceKey = this.sourceKey;
    this.dialogOptions = await ComicSourceService.getInstance().getSourceSearchOptions(this.dialogSourceKey);
    const values: string[] = [];
    for (let i = 0; i < this.dialogOptions.length; i++) {
      values.push(this.searchOptions[i] ?? this.dialogOptions[i].defaultValue);
    }
    this.dialogOptionValues = values;
    this.showSettings = true;
  }

  private applySettingsAndSearch(): void {
    this.sourceKey = this.dialogSourceKey;
    const src = this.allSearchSources.find((s: SearchPageSourceItem) => s.key === this.sourceKey);
    if (src) {
      this.sourceName = src.name;
    }
    this.searchOptions = [...this.dialogOptionValues];
    this.showSettings = false;
    this.rerunSearch();
  }

  private buildOptionSelectItems(def: SearchOptionDef): SearchOptionSelectItem[] {
    const out: SearchOptionSelectItem[] = [];
    for (let i = 0; i < def.options.length; i++) {
      const label = def.options[i].text.length > 0 ? def.options[i].text : def.options[i].value;
      out.push({ value: label });
    }
    return out;
  }

  private optionSelectIndex(def: SearchOptionDef, optionIndex: number): number {
    const current = this.dialogOptionValues[optionIndex] ?? def.defaultValue;
    for (let i = 0; i < def.options.length; i++) {
      if (def.options[i].value === current) {
        return i;
      }
    }
    return 0;
  }

  private async selectDialogSource(key: string): Promise<void> {
    this.dialogSourceKey = key;
    this.dialogOptions = await ComicSourceService.getInstance().getSourceSearchOptions(key);
    const values: string[] = [];
    for (let i = 0; i < this.dialogOptions.length; i++) {
      values.push(this.dialogOptions[i].defaultValue);
    }
    this.dialogOptionValues = values;
  }

  build() {
    Stack() {
      Column() {
        SecondaryPageHeader({
          title: this.sourceName.length > 0 ? this.sourceName : $r('app.string.search')
        })

        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索…', text: this.keyword })
            .layoutWeight(1)
            .onChange((v: string) => this.onKeywordChange(v))
            .onSubmit(() => this.rerunSearch())
          Row() {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .fontSize(20)
              .fontColor([SysTheme.FONT_SECONDARY])
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => this.openSettingsDialog())
          Button('搜索')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .height(36)
            .onClick(() => this.rerunSearch())
        }
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.suggestions.length > 0) {
          this.buildSuggestionsPanel()
        }

        if (this.loading) {
          LoadingProgress().width(48).height(48).margin(24)
        } else if (this.error.length > 0) {
          Text(this.error)
            .fontSize(14)
            .fontColor('#FFE53935')
            .padding(16)
            .layoutWeight(1)
        } else if (this.comics.length === 0) {
          Text($r('app.string.search_no_results'))
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
            }, (c: Comic) => `${c.sourceKey}_${c.id}_${this.listVersion}`)

            if (this.canLoadMore()) {
              ListItem() {
                Row() {
                  Button('加载更多')
                    .type(ButtonType.Capsule)
                    .height(36)
                    .onClick(() => this.loadPage(this.currentPage + 1, false))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding(16)
              }
            }

            if (this.loadingMore) {
              ListItem() {
                LoadingProgress().width(32).height(32).margin(16)
              }
            }
          }
          .layoutWeight(1)
          .onReachEnd(() => {
            if (this.canLoadMore()) {
              this.loadPage(this.currentPage + 1, false);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding(SafeAreaInsets.pagePadding())
      .backgroundColor(SysTheme.BACKGROUND_PRIMARY)

      if (this.showSettings) {
        this.buildSettingsOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildSuggestionsPanel() {
    Row() {
      Text($r('app.string.suggestions'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
      Text($r('app.string.clear'))
        .fontSize(13)
        .fontColor(SysTheme.EMPHASIZE)
        .onClick(() => {
          this.suggestions = [];
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })

    ForEach(this.suggestions, (item: TagSuggestion) => {
      Row() {
        Column() {
          Text(item.tag)
            .fontSize(14)
            .fontColor(SysTheme.FONT_PRIMARY)
          if (TagTranslationService.isEnabled()) {
            Text(TagTranslationService.translationTagWithNamespace(item.tag, item.namespace))
              .fontSize(12)
              .fontColor(SysTheme.FONT_SECONDARY)
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(item.namespace)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => {
        this.applyTagSuggestion(item);
      })
    }, (item: TagSuggestion) => `res_${item.namespace}_${item.tag}`)
  }

  @Builder
  buildSettingsOverlay() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showSettings = false;
        })

      Column() {
        Text($r('app.string.search_settings'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
          .margin({ bottom: 12 })

        Text($r('app.string.search_in'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .width('100%')
          .margin({ bottom: 8 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.allSearchSources, (src: SearchPageSourceItem) => {
            Text(src.name)
              .fontSize(12)
              .fontColor(this.dialogSourceKey === src.key ? SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
              .backgroundColor(this.dialogSourceKey === src.key ? '#1A0A59F7' : SysTheme.BACKGROUND_SECONDARY)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(8)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.selectDialogSource(src.key))
          }, (src: SearchPageSourceItem) => src.key)
        }
        .width('100%')
        .margin({ bottom: 12 })

        ForEach(this.dialogOptions, (def: SearchOptionDef, index: number) => {
          Row() {
            Text(def.label.length > 0 ? def.label : `选项 ${index + 1}`)
              .fontSize(14)
              .fontColor(SysTheme.FONT_PRIMARY)
              .layoutWeight(1)
            if (def.options.length > 0) {
              Select(this.buildOptionSelectItems(def))
                .selected(this.optionSelectIndex(def, index))
                .value(this.buildOptionSelectItems(def)[this.optionSelectIndex(def, index)].value)
                .onSelect((sel: number) => {
                  if (sel >= 0 && sel < def.options.length) {
                    this.dialogOptionValues[index] = def.options[sel].value;
                    this.dialogOptionValues = [...this.dialogOptionValues];
                  }
                })
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }, (def: SearchOptionDef, index: number) => `dlg_${def.label}_${index}`)

        Button($r('app.string.confirm'))
          .type(ButtonType.Capsule)
          .width('100%')
          .margin({ top: 16 })
          .onClick(() => this.applySettingsAndSearch())
      }
      .width('100%')
      .padding(20)
      .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }
}
