import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ComicSourceInfo } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 探索相关设置 — 对齐 upstream lib/pages/settings/explore_settings.dart
 */
@Entry
@Component
struct ExploreSettingsPage {
  @State comicDisplayMode: string = 'detailed';
  @State comicTileScale: number = 1.0;
  @State showFavoriteOnTile: boolean = true;
  @State showHistoryOnTile: boolean = false;
  @State reverseChapterOrder: boolean = false;
  @State autoLanguageFilter: string = 'none';
  @State defaultSearchTarget: string = '';
  @State initialPage: number = 0;
  @State comicListDisplayMode: string = 'paging';
  @State sources: ComicSourceInfo[] = [];
  @State showSearchTargetPicker: boolean = false;

  aboutToAppear(): void {
    this.reloadFromSettings();
    this.sources = ComicSourceService.getInstance().getSources();
  }

  private reloadFromSettings(): void {
    const s = AppDataService.getInstance().settings;
    this.comicDisplayMode = s.comicDisplayMode;
    this.comicTileScale = s.comicTileScale;
    this.showFavoriteOnTile = s.showFavoriteStatusOnTile;
    this.showHistoryOnTile = s.showHistoryStatusOnTile;
    this.reverseChapterOrder = s.reverseChapterOrder;
    this.autoLanguageFilter = s.autoAddLanguageFilter.length > 0 ? s.autoAddLanguageFilter : 'none';
    this.defaultSearchTarget = s.defaultSearchTarget;
    this.initialPage = s.initialPage;
    this.comicListDisplayMode = s.comicListDisplayMode;
  }

  private async save(): Promise<void> {
    await AppDataService.getInstance().save();
  }

  private displayModeLabel(): string {
    return this.comicDisplayMode === 'brief' ? '简略' : '详细';
  }

  private cycleDisplayMode(): void {
    this.comicDisplayMode = this.comicDisplayMode === 'detailed' ? 'brief' : 'detailed';
    AppDataService.getInstance().settings.comicDisplayMode = this.comicDisplayMode;
    this.save();
  }

  private autoLanguageLabel(): string {
    if (this.autoLanguageFilter === 'chinese') {
      return '中文';
    }
    if (this.autoLanguageFilter === 'english') {
      return '英文';
    }
    if (this.autoLanguageFilter === 'japanese') {
      return '日文';
    }
    return '无';
  }

  private cycleAutoLanguageFilter(): void {
    const order = ['none', 'chinese', 'english', 'japanese'];
    let idx = order.indexOf(this.autoLanguageFilter);
    if (idx < 0) {
      idx = 0;
    }
    idx = (idx + 1) % order.length;
    this.autoLanguageFilter = order[idx];
    AppDataService.getInstance().settings.autoAddLanguageFilter = this.autoLanguageFilter;
    this.save();
  }

  private initialPageLabel(): string {
    if (this.initialPage === 1) {
      return '收藏';
    }
    if (this.initialPage === 2) {
      return '发现';
    }
    if (this.initialPage === 3) {
      return '分类';
    }
    return '首页';
  }

  private cycleInitialPage(): void {
    this.initialPage = (this.initialPage + 1) % 4;
    AppDataService.getInstance().settings.initialPage = this.initialPage;
    this.save();
  }

  private listDisplayLabel(): string {
    return this.comicListDisplayMode === 'continuous' ? '连续' : '分页';
  }

  private cycleListDisplayMode(): void {
    this.comicListDisplayMode =
      this.comicListDisplayMode === 'paging' ? 'continuous' : 'paging';
    AppDataService.getInstance().settings.comicListDisplayMode = this.comicListDisplayMode;
    this.save();
  }

  private defaultSearchLabel(): string {
    if (this.defaultSearchTarget === '_aggregated_') {
      return '聚合';
    }
    if (this.defaultSearchTarget.length === 0) {
      return '未设置';
    }
    const src = ComicSourceService.getInstance().getSourceByKey(this.defaultSearchTarget);
    return src && src.name.length > 0 ? src.name : this.defaultSearchTarget;
  }

  private setDefaultSearchTarget(key: string): void {
    this.defaultSearchTarget = key;
    AppDataService.getInstance().settings.defaultSearchTarget = key;
    this.showSearchTargetPicker = false;
    this.save();
  }

  @Builder
  navRow(title: ResourceStr, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(SysTheme.FONT_PRIMARY)
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([SysTheme.FONT_SECONDARY])
    }
    .width('100%')
    .padding(16)
    .onClick(onClick)
  }

  @Builder
  selectRow(title: ResourceStr, value: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(SysTheme.FONT_PRIMARY)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(SysTheme.FONT_SECONDARY)
    }
    .width('100%')
    .padding(16)
    .onClick(onClick)
  }

  @Builder
  switchRow(title: ResourceStr, isOn: boolean, onChange: (on: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange)
    }
    .width('100%')
    .padding(16)
  }

  build() {
    Stack() {
      Column() {
        SecondaryPageHeader({ title: $r('app.string.explore_settings') })

        List() {
          ListItem() {
            this.selectRow($r('app.string.comic_tile_display_mode'), this.displayModeLabel(),
              () => this.cycleDisplayMode())
          }
          ListItem() {
            Column() {
              Text($r('app.string.comic_tile_scale'))
                .fontSize(16)
                .fontColor(SysTheme.FONT_PRIMARY)
                .width('100%')
              Slider({
                value: this.comicTileScale,
                min: 0.5,
                max: 1.5,
                step: 0.05
              })
                .margin({ top: 8 })
                .onChange((v: number) => {
                  this.comicTileScale = v;
                  AppDataService.getInstance().settings.comicTileScale = v;
                  this.save();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
          }
          ListItem() {
            this.navRow($r('app.string.explore_pages_settings'), () => {
              router.pushUrl({ url: 'pages/explore/ExplorePagesPickerPage' });
            })
          }
          ListItem() {
            this.navRow($r('app.string.category_pages_settings'), () => {
              router.pushUrl({ url: 'pages/settings/CategoryPagesPickerPage' });
            })
          }
          ListItem() {
            this.navRow($r('app.string.network_favorites_settings'), () => {
              router.pushUrl({ url: 'pages/favorites/NetworkFavoritesPickerPage' });
            })
          }
          ListItem() {
            this.navRow($r('app.string.search_sources_settings'), () => {
              router.pushUrl({ url: 'pages/settings/SearchSourcesSettingsPage' });
            })
          }
          ListItem() {
            this.switchRow($r('app.string.show_favorite_on_tile'), this.showFavoriteOnTile, (on: boolean) => {
              this.showFavoriteOnTile = on;
              AppDataService.getInstance().settings.showFavoriteStatusOnTile = on;
              this.save();
            })
          }
          ListItem() {
            this.switchRow($r('app.string.show_history_on_tile'), this.showHistoryOnTile, (on: boolean) => {
              this.showHistoryOnTile = on;
              AppDataService.getInstance().settings.showHistoryStatusOnTile = on;
              this.save();
            })
          }
          ListItem() {
            this.switchRow($r('app.string.reverse_chapter_order'), this.reverseChapterOrder, (on: boolean) => {
              this.reverseChapterOrder = on;
              AppDataService.getInstance().settings.reverseChapterOrder = on;
              this.save();
            })
          }
          ListItem() {
            this.navRow($r('app.string.blocked_words_settings'), () => {
              router.pushUrl({
                url: 'pages/settings/BlockingWordsPage',
                params: { kind: 'comic' }
              });
            })
          }
          ListItem() {
            this.navRow($r('app.string.blocked_comment_words_settings'), () => {
              router.pushUrl({
                url: 'pages/settings/BlockingWordsPage',
                params: { kind: 'comment' }
              });
            })
          }
          ListItem() {
            this.selectRow($r('app.string.default_search_target'), this.defaultSearchLabel(), () => {
              this.showSearchTargetPicker = true;
            })
          }
          ListItem() {
            this.selectRow($r('app.string.auto_language_filter'), this.autoLanguageLabel(),
              () => this.cycleAutoLanguageFilter())
          }
          ListItem() {
            this.selectRow($r('app.string.initial_page'), this.initialPageLabel(),
              () => this.cycleInitialPage())
          }
          ListItem() {
            this.selectRow($r('app.string.comic_list_display_mode'), this.listDisplayLabel(),
              () => this.cycleListDisplayMode())
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      if (this.showSearchTargetPicker) {
        Column() {
          Row() {
            Text($r('app.string.default_search_target'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .onClick(() => {
                this.showSearchTargetPicker = false;
              })
          }
          .width('100%')
          .padding(16)

          List() {
            ListItem() {
              Row() {
                Text($r('app.string.aggregated_search'))
                  .fontSize(16)
                Blank()
                if (this.defaultSearchTarget === '_aggregated_') {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(18)
                    .fontColor([SysTheme.EMPHASIZE])
                }
              }
              .width('100%')
              .padding(16)
              .onClick(() => this.setDefaultSearchTarget('_aggregated_'))
            }
            ForEach(this.sources, (src: ComicSourceInfo) => {
              ListItem() {
                Row() {
                  Text(src.name)
                    .fontSize(16)
                  Blank()
                  if (this.defaultSearchTarget === src.key) {
                    SymbolGlyph($r('sys.symbol.checkmark'))
                      .fontSize(18)
                      .fontColor([SysTheme.EMPHASIZE])
                  }
                }
                .width('100%')
                .padding(16)
                .onClick(() => this.setDefaultSearchTarget(src.key))
              }
            }, (src: ComicSourceInfo) => src.key)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
        .padding(SafeAreaInsets.pagePadding())
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
