import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { AppDataService } from '../../common/services/AppDataService';
import {
  SearchOptionDef,
  SearchPageSourceItem,
  SearchSuggestionContext,
  SourceSettingOption
} from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { TagSuggestion, TagTranslationService } from '../../common/services/TagTranslationService';
import { SearchUtil } from '../../common/utils/SearchUtil';

interface SearchOptionSelectItem {
  value: string;
}

/**
 * 搜索页 — 对齐 upstream lib/pages/search_page.dart
 * 源芯片 / 聚合搜索 / 搜索选项 / 标签建议 / 搜索历史
 */
@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State history: string[] = AppDataService.getInstance().searchHistory;
  @State searchSources: SearchPageSourceItem[] = [];
  @State searchTarget: string = '';
  @State aggregatedSearch: boolean = false;
  @State searchOptions: SearchOptionDef[] = [];
  @State optionValues: string[] = [];
  @State loadingSources: boolean = true;
  @State deepLinkSourceKey: string = '';
  @State deepLinkSourceName: string = '';
  @State suggestions: TagSuggestion[] = [];
  @State tagSuggestionsEnabled: boolean = false;
  @State noInstalledSources: boolean = false;
  @State suggestionContext: SearchSuggestionContext = new SearchSuggestionContext();
  private suggestionRequestId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.deepLinkSourceKey = params['sourceKey'] ?? '';
    this.deepLinkSourceName = params['sourceName'] ?? '';
    const kw = params['keyword'] ?? '';
    if (kw.length > 0) {
      this.keyword = kw;
    }
    this.refreshSearchSources();
  }

  onPageShow(): void {
    this.refreshSearchSources();
    this.history = AppDataService.getInstance().searchHistory;
  }

  private async refreshSearchSources(): Promise<void> {
    this.loadingSources = true;
    await ComicSourceService.getInstance().ensureEngineReady();
    this.noInstalledSources = !ComicSourceService.getInstance().hasAnyInstalledSource();
    this.searchSources = await ComicSourceService.getInstance().getSearchPageSources();
    this.applyDefaultTarget();
    if (this.searchTarget.length > 0 && !this.aggregatedSearch) {
      await this.loadSearchOptions(this.searchTarget);
      this.tagSuggestionsEnabled =
        await ComicSourceService.getInstance().isSourceTagSuggestionsEnabled(this.searchTarget);
    } else {
      this.searchOptions = [];
      this.optionValues = [];
      this.tagSuggestionsEnabled = false;
    }
    this.refreshSuggestionsAsync();
    this.loadingSources = false;
  }

  private applyDefaultTarget(): void {
    if (this.searchSources.length === 0) {
      this.searchTarget = '';
      return;
    }
    if (this.deepLinkSourceKey.length > 0) {
      const found = this.searchSources.find((s: SearchPageSourceItem) => s.key === this.deepLinkSourceKey);
      if (found) {
        this.searchTarget = found.key;
        this.aggregatedSearch = false;
        return;
      }
    }
    const def = AppDataService.getInstance().settings.defaultSearchTarget;
    if (def === '_aggregated_') {
      this.aggregatedSearch = true;
      this.searchTarget = this.searchSources[0].key;
      return;
    }
    if (def.length > 0 && this.searchSources.some((s: SearchPageSourceItem) => s.key === def)) {
      this.searchTarget = def;
      this.aggregatedSearch = false;
      return;
    }
    this.searchTarget = this.searchSources[0].key;
    this.aggregatedSearch = false;
  }

  private saveDefaultTarget(): void {
    const settings = AppDataService.getInstance().settings;
    settings.defaultSearchTarget = this.aggregatedSearch ? '_aggregated_' : this.searchTarget;
    AppDataService.getInstance().save();
  }

  private async loadSearchOptions(sourceKey: string): Promise<void> {
    const defs = await ComicSourceService.getInstance().getSourceSearchOptions(sourceKey);
    const values: string[] = [];
    for (let i = 0; i < defs.length; i++) {
      values.push(defs[i].defaultValue);
    }
    this.searchOptions = defs;
    this.optionValues = values;
  }

  private async selectSource(key: string): Promise<void> {
    if (this.aggregatedSearch) {
      return;
    }
    this.searchTarget = key;
    this.saveDefaultTarget();
    await this.loadSearchOptions(key);
    this.tagSuggestionsEnabled =
      await ComicSourceService.getInstance().isSourceTagSuggestionsEnabled(key);
    this.refreshSuggestionsAsync();
  }

  private toggleAggregated(on: boolean): void {
    this.aggregatedSearch = on;
    this.saveDefaultTarget();
    if (on) {
      this.searchOptions = [];
      this.optionValues = [];
      this.tagSuggestionsEnabled = false;
    } else if (this.searchTarget.length > 0) {
      this.loadSearchOptions(this.searchTarget);
      ComicSourceService.getInstance().isSourceTagSuggestionsEnabled(this.searchTarget)
        .then((enabled: boolean) => {
          this.tagSuggestionsEnabled = enabled;
          this.refreshSuggestionsAsync();
        });
    }
    this.refreshSuggestionsAsync();
  }

  private onKeywordChange(v: string): void {
    this.keyword = v;
    this.refreshSuggestionsAsync();
  }

  private refreshSuggestionsAsync(): void {
    const req = ++this.suggestionRequestId;
    const svc = ComicSourceService.getInstance();
    svc.getSearchSuggestionContext(this.keyword).then((ctx: SearchSuggestionContext) => {
      if (req !== this.suggestionRequestId) {
        return;
      }
      this.suggestionContext = ctx;
      if (ctx.linkSourceKey.length > 0 || ctx.idMatchSources.length > 0) {
        this.suggestions = [];
        return;
      }
      if (this.aggregatedSearch || !this.tagSuggestionsEnabled) {
        this.suggestions = [];
        return;
      }
      const token = SearchUtil.getLastToken(this.keyword);
      if (token.length === 0) {
        this.suggestions = [];
        return;
      }
      this.suggestions = TagTranslationService.findTagSuggestions(token, 100);
    }).catch((e: Error) => {
      console.warn(`[SearchPage] refreshSuggestions: ${e}`);
    });
  }

  private async applyTagSuggestion(item: TagSuggestion): Promise<void> {
    let base = SearchUtil.removeTrailingToken(this.keyword, item.tag);
    if (base.length > 0 && !base.endsWith(' ')) {
      base += ' ';
    }
    const insert = await ComicSourceService.getInstance()
      .formatTagSuggestionInsert(this.searchTarget, item.namespace, item.tag);
    this.keyword = base + insert;
    this.suggestions = [];
    this.refreshSuggestionsAsync();
  }

  private openComicFromLink(): void {
    const ctx = this.suggestionContext;
    if (ctx.linkSourceKey.length === 0 || ctx.linkComicId.length === 0) {
      return;
    }
    ComicSourceService.getInstance().openComicDetail(ctx.linkSourceKey, ctx.linkComicId);
  }

  private openComicById(sourceKey: string): void {
    ComicSourceService.getInstance().openComicDetail(sourceKey, this.keyword.trim());
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
    const current = this.optionValues[optionIndex] ?? def.defaultValue;
    for (let i = 0; i < def.options.length; i++) {
      if (def.options[i].value === current) {
        return i;
      }
    }
    return 0;
  }

  private parseMultiValue(raw: string): string[] {
    try {
      const arr = JSON.parse(raw) as string[];
      return Array.isArray(arr) ? arr : [];
    } catch (_e) {
      return [];
    }
  }

  private isMultiSelected(optionIndex: number, key: string): boolean {
    const raw = this.optionValues[optionIndex] ?? '[]';
    return this.parseMultiValue(raw).indexOf(key) >= 0;
  }

  private toggleMultiOption(optionIndex: number, key: string): void {
    const list = this.parseMultiValue(this.optionValues[optionIndex] ?? '[]');
    const idx = list.indexOf(key);
    if (idx >= 0) {
      list.splice(idx, 1);
    } else {
      list.push(key);
    }
    this.optionValues[optionIndex] = JSON.stringify(list);
    this.optionValues = [...this.optionValues];
  }

  private doSearch(): void {
    const word = this.keyword.trim();
    if (word.length === 0) {
      return;
    }
    if (this.searchSources.length === 0) {
      return;
    }
    this.suggestions = [];
    AppDataService.getInstance().addSearchHistory(word);
    this.history = AppDataService.getInstance().searchHistory;
    if (this.aggregatedSearch) {
      router.pushUrl({
        url: 'pages/search/AggregatedSearchPage',
        params: { keyword: word }
      });
      return;
    }
    if (this.searchTarget.length === 0) {
      return;
    }
    const src = this.searchSources.find((s: SearchPageSourceItem) => s.key === this.searchTarget);
    const finalKeyword = SearchUtil.checkAutoLanguage(word, this.searchTarget);
    router.pushUrl({
      url: 'pages/search/SearchResultPage',
      params: {
        sourceKey: this.searchTarget,
        sourceName: src?.name ?? this.searchTarget,
        keyword: finalKeyword,
        options: JSON.stringify(this.optionValues)
      }
    });
  }

  private openManageSources(): void {
    router.pushUrl({ url: 'pages/settings/SearchSourcesSettingsPage' });
  }

  private openComicSources(): void {
    router.pushUrl({ url: 'pages/sources/ComicSourcePage' });
  }

  private async copyHistoryItem(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const sysBoard = pasteboard.getSystemPasteboard();
      await sysBoard.setData(data);
      promptAction.showToast({ message: $r('app.string.copy'), duration: 1500 });
    } catch (e) {
      console.warn(`[SearchPage] copy failed: ${e}`);
    }
  }

  private clearAllHistory(): void {
    AppDataService.getInstance().clearSearchHistory();
    this.history = [];
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.search') })

      if (this.loadingSources) {
        LoadingProgress().width(32).height(32).margin({ top: 24 })
      } else if (this.searchSources.length === 0) {
        this.buildEmptyState()
      } else {
        this.buildSearchBody()
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  buildEmptyState() {
    Column() {
      Text($r('app.string.no_search_sources'))
        .fontSize(15)
        .fontColor(SysTheme.FONT_PRIMARY)
        .margin({ top: 24, bottom: 8 })
      Text(this.noInstalledSources ?
        $r('app.string.no_search_sources_add') : $r('app.string.no_search_sources_settings'))
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
      Button(this.noInstalledSources ? $r('app.string.comic_sources') : $r('app.string.search_sources_settings'))
        .type(ButtonType.Capsule)
        .margin({ top: 16 })
        .onClick(() => this.noInstalledSources ? this.openComicSources() : this.openManageSources())
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildSearchBody() {
    Scroll() {
      Column() {
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索漫画…', text: this.keyword })
            .layoutWeight(1)
            .onChange((v: string) => this.onKeywordChange(v))
            .onSubmit(() => this.doSearch())
          Button('搜索')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .onClick(() => this.doSearch())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.suggestionContext.linkSourceKey.length > 0) {
          this.buildComicLinkSuggestion()
        } else if (this.suggestionContext.idMatchSources.length > 0) {
          this.buildIdMatchSuggestions()
        } else if (this.suggestions.length > 0) {
          this.buildSuggestionsPanel()
        } else {
          this.buildSourceAndOptions()
          this.buildHistorySection()
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildComicLinkSuggestion() {
    Row() {
      SymbolGlyph($r('sys.symbol.link'))
        .fontSize(18)
        .fontColor([SysTheme.EMPHASIZE])
        .margin({ right: 8 })
      Column() {
        Text($r('app.string.open_link'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_PRIMARY)
        Text(this.keyword)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([SysTheme.FONT_SECONDARY])
    }
    .width('100%')
    .padding(16)
    .onClick(() => this.openComicFromLink())
  }

  @Builder
  buildIdMatchSuggestions() {
    ForEach(this.suggestionContext.idMatchSources, (src: SearchPageSourceItem) => {
      Row() {
        SymbolGlyph($r('sys.symbol.link'))
          .fontSize(18)
          .fontColor([SysTheme.EMPHASIZE])
          .margin({ right: 8 })
        Column() {
          Row() {
            Text($r('app.string.open_comic'))
              .fontSize(14)
              .fontColor(SysTheme.FONT_PRIMARY)
            Text(`: ${src.name}`)
              .fontSize(14)
              .fontColor(SysTheme.FONT_PRIMARY)
          }
          Text(this.keyword)
            .fontSize(12)
            .fontColor(SysTheme.FONT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([SysTheme.FONT_SECONDARY])
      }
      .width('100%')
      .padding(16)
      .onClick(() => this.openComicById(src.key))
    }, (src: SearchPageSourceItem) => `id_${src.key}`)
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
    .padding({ left: 16, right: 16, top: 8 })

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
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => {
        this.applyTagSuggestion(item);
      })
    }, (item: TagSuggestion) => `${item.namespace}_${item.tag}`)
  }

  @Builder
  buildSourceAndOptions() {
    Row() {
      Text($r('app.string.search_in'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
      Row() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(20)
          .fontColor([SysTheme.FONT_SECONDARY])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.openManageSources())
    }
    .width('100%')
    .padding({ left: 16, right: 8 })

    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.searchSources, (src: SearchPageSourceItem) => {
        Text(src.name)
          .fontSize(12)
          .fontColor((!this.aggregatedSearch && this.searchTarget === src.key) ?
            SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
          .backgroundColor((!this.aggregatedSearch && this.searchTarget === src.key) ?
            '#1A0A59F7' : SysTheme.BACKGROUND_SECONDARY)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => this.selectSource(src.key))
      }, (src: SearchPageSourceItem) => src.key)
    }
    .padding({ left: 16, right: 16 })

    Row() {
      Checkbox({ name: 'aggregated', group: 'searchMode' })
        .select(this.aggregatedSearch)
        .onChange((on: boolean) => this.toggleAggregated(on))
      Text($r('app.string.aggregated_search'))
        .fontSize(14)
        .fontColor(SysTheme.FONT_PRIMARY)
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 4, bottom: 8 })

    if (!this.aggregatedSearch && this.searchOptions.length > 0) {
      Column() {
        ForEach(this.searchOptions, (def: SearchOptionDef, index: number) => {
          Column() {
            Text(def.label.length > 0 ? def.label : `选项 ${index + 1}`)
              .fontSize(14)
              .fontColor(SysTheme.FONT_PRIMARY)
              .width('100%')
              .margin({ bottom: 6 })
            if (def.type === 'multi-select' || def.type === 'select') {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(def.options, (opt: SourceSettingOption) => {
                  Text(opt.text.length > 0 ? opt.text : opt.value)
                    .fontSize(12)
                    .fontColor((def.type === 'multi-select' ?
                      this.isMultiSelected(index, opt.value) :
                      (this.optionValues[index] ?? def.defaultValue) === opt.value) ?
                      SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
                    .backgroundColor((def.type === 'multi-select' ?
                      this.isMultiSelected(index, opt.value) :
                      (this.optionValues[index] ?? def.defaultValue) === opt.value) ?
                      '#1A0A59F7' : SysTheme.BACKGROUND_SECONDARY)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(8)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => {
                      if (def.type === 'multi-select') {
                        this.toggleMultiOption(index, opt.value);
                      } else {
                        this.optionValues[index] = opt.value;
                        this.optionValues = [...this.optionValues];
                      }
                    })
                }, (opt: SourceSettingOption) => opt.value)
              }
            } else if (def.options.length > 0) {
              Select(this.buildOptionSelectItems(def))
                .selected(this.optionSelectIndex(def, index))
                .value(this.buildOptionSelectItems(def)[this.optionSelectIndex(def, index)].value)
                .onSelect((sel: number) => {
                  if (sel >= 0 && sel < def.options.length) {
                    this.optionValues[index] = def.options[sel].value;
                    this.optionValues = [...this.optionValues];
                  }
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 8, bottom: 8 })
        }, (def: SearchOptionDef, index: number) => `${def.label}_${index}`)
      }
      .padding({ left: 16, right: 16, bottom: 8 })
    }
  }

  @Builder
  buildHistorySection() {
    if (this.history.length > 0) {
      Row() {
        Text($r('app.string.search_history'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .layoutWeight(1)
        Text($r('app.string.clear'))
          .fontSize(13)
          .fontColor(SysTheme.EMPHASIZE)
          .onClick(() => this.clearAllHistory())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Column() {
        ForEach(this.history, (h: string) => {
          Row() {
            Text(h)
              .fontSize(13)
              .fontColor(SysTheme.FONT_PRIMARY)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.copy'))
              .fontSize(12)
              .fontColor(SysTheme.EMPHASIZE)
              .margin({ left: 8 })
              .onClick(() => this.copyHistoryItem(h))
            Text($r('app.string.delete'))
              .fontSize(12)
              .fontColor('#FFE53935')
              .margin({ left: 8 })
              .onClick(() => {
                AppDataService.getInstance().removeSearchHistory(h);
                this.history = AppDataService.getInstance().searchHistory;
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .border({
            width: { left: 2 },
            color: SysTheme.BACKGROUND_SECONDARY
          })
          .margin({ bottom: 8 })
          .onClick(() => {
            this.keyword = h;
            this.doSearch();
          })
        }, (h: string) => h)
      }
      .padding({ left: 16, right: 16, bottom: 24 })
    }
  }
}
