import { router } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { SingleExplorePanel } from './SingleExplorePanel';
import { ENGINE_READY_KEY } from '../../common/constants/StartupKeys';

/**
 * 发现 — 对齐 upstream explore_page.dart（explore_pages 多 Tab）。
 * 漫画源管理见 ComicSourcePage。
 */
@Component
export struct ExplorePage {
  scroller: Scroller = new Scroller();
  @State pages: string[] = [];
  @State exploreTabIndex: number = 0;
  @State refreshToken: number = 0;
  @StorageLink(ENGINE_READY_KEY) @Watch('onEngineReadyChanged') engineReady: boolean = false;

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

  private reloadPages(): void {
    ComicSourceService.getInstance().getConfiguredExplorePages().then((pages: string[]) => {
      this.pages = pages;
      if (this.exploreTabIndex >= this.pages.length) {
        this.exploreTabIndex = 0;
      }
    });
  }

  private refreshCurrentTab(): void {
    this.refreshToken++;
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button($r('app.string.comic_sources'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .onClick(() => router.pushUrl({ url: 'pages/sources/ComicSourcePage' }))
        Button($r('app.string.explore_add_pages'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .onClick(() => router.pushUrl({ url: 'pages/explore/ExplorePagesPickerPage' }))
        Blank()
        if (this.pages.length > 0) {
          Button($r('app.string.refresh_sources'))
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(12)
            .onClick(() => this.refreshCurrentTab())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      if (this.pages.length === 0) {
        Column({ space: 12 }) {
          Text($r('app.string.explore_no_pages'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .textAlign(TextAlign.Center)
          Button($r('app.string.explore_add_pages'))
            .type(ButtonType.Capsule)
            .onClick(() => router.pushUrl({ url: 'pages/explore/ExplorePagesPickerPage' }))
          Button($r('app.string.comic_sources'))
            .type(ButtonType.Normal)
            .onClick(() => router.pushUrl({ url: 'pages/sources/ComicSourcePage' }))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else {
        Tabs({ index: this.exploreTabIndex }) {
          ForEach(this.pages, (title: string) => {
            TabContent() {
              SingleExplorePanel({
                pageTitle: title,
                scroller: this.scroller,
                refreshTick: this.refreshToken
              })
            }.tabBar(title)
          }, (title: string) => title)
        }
        .barMode(BarMode.Scrollable)
        .onChange((index: number) => {
          this.exploreTabIndex = index;
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: ShellInsets.FLOATING_BAR_RESERVE })
  }
}
