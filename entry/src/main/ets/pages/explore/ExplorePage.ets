import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { SingleExplorePanel } from './SingleExplorePanel';
import { ENGINE_READY_KEY, EXPLORE_SCROLL_TOP_KEY } from '../../common/constants/StartupKeys';

/**
 * 发现 — 对齐 upstream explore_page.dart（explore_pages 多 Tab、FAB 刷新、空状态）
 */
@Component
export struct ExplorePage {
  @State pages: string[] = [];
  @State tabLabels: string[] = [];
  @State exploreTabIndex: number = 0;
  @State refreshToken: number = 0;
  @State showFab: boolean = true;
  @State noInstalledSources: boolean = false;
  @StorageLink(ENGINE_READY_KEY) @Watch('onEngineReadyChanged') engineReady: boolean = false;
  private scrollY: number = 0;

  aboutToAppear(): void {
    this.tryReloadPages();
  }

  onPageShow(): void {
    this.tryReloadPages();
  }

  onEngineReadyChanged(): void {
    this.tryReloadPages();
  }

  private tryReloadPages(): void {
    if (!this.engineReady) {
      return;
    }
    this.reloadPages();
  }

  private async reloadPages(): Promise<void> {
    this.noInstalledSources = !ComicSourceService.getInstance().hasAnyInstalledSource();
    const pages = await ComicSourceService.getInstance().getConfiguredExplorePages();
    this.pages = pages;
    if (this.exploreTabIndex >= this.pages.length) {
      this.exploreTabIndex = 0;
    }
    const labels: string[] = [];
    for (let i = 0; i < pages.length; i++) {
      labels.push(await ComicSourceService.getInstance().getExploreTabLabel(pages[i]));
    }
    this.tabLabels = labels;
  }

  scrollCurrentToTop(): void {
    const prev = AppStorage.get<number>(EXPLORE_SCROLL_TOP_KEY) ?? 0;
    AppStorage.setOrCreate(EXPLORE_SCROLL_TOP_KEY, prev + 1);
  }

  private refreshCurrentTab(): void {
    this.refreshToken++;
  }

  private onScrollOffset(y: number): void {
    if (y > this.scrollY && y > 0 && this.showFab) {
      this.showFab = false;
    } else if ((y < this.scrollY - 50 || y <= 0) && !this.showFab) {
      this.showFab = true;
    }
    this.scrollY = y;
  }

  private openAddPages(): void {
    router.pushUrl({ url: 'pages/explore/ExplorePagesPickerPage' });
  }

  private openComicSources(): void {
    router.pushUrl({ url: 'pages/sources/ComicSourcePage' });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        if (this.pages.length === 0) {
          this.buildEmptyState()
        } else {
          this.buildTabBar()
          if (this.pages.length > 0 && this.exploreTabIndex < this.pages.length) {
            SingleExplorePanel({
              pageTitle: this.pages[this.exploreTabIndex],
              refreshTick: this.refreshToken,
              onScrollOffset: (y: number) => this.onScrollOffset(y)
            })
              .layoutWeight(1)
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: ShellInsets.FLOATING_BAR_RESERVE })

      if (this.showFab && this.pages.length > 0) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor([Color.White])
        }
        .width(52)
        .height(52)
        .backgroundColor(SysTheme.EMPHASIZE)
        .margin({ right: 16, bottom: 16 })
        .onClick(() => this.refreshCurrentTab())
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildEmptyState() {
    Column({ space: 12 }) {
      Text($r('app.string.no_explore_pages'))
        .fontSize(15)
        .fontColor(SysTheme.FONT_PRIMARY)
        .margin({ top: 24 })
      Text(this.noInstalledSources ?
        $r('app.string.no_explore_pages_add') : $r('app.string.no_explore_pages_settings'))
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
      Button(this.noInstalledSources ? $r('app.string.comic_sources') : $r('app.string.manage'))
        .type(ButtonType.Capsule)
        .margin({ top: 8 })
        .onClick(() => this.noInstalledSources ? this.openComicSources() : this.openAddPages())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildTabBar() {
    Scroll() {
      Row() {
        ForEach(this.pages, (title: string, index: number) => {
          Text(this.tabLabels[index] ?? title)
            .fontSize(13)
            .fontColor(this.exploreTabIndex === index ? SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
            .fontWeight(this.exploreTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .backgroundColor(this.exploreTabIndex === index ? '#1A0A59F7' : SysTheme.BACKGROUND_SECONDARY)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(8)
            .margin({ right: 8 })
            .onClick(() => {
              this.exploreTabIndex = index;
            })
        }, (title: string) => title)

        Row() {
          Text('+')
            .fontSize(14)
            .fontColor(SysTheme.EMPHASIZE)
            .margin({ right: 4 })
          Text($r('app.string.add'))
            .fontSize(13)
            .fontColor(SysTheme.EMPHASIZE)
        }
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .onClick(() => this.openAddPages())
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
