import { router } from '@kit.ArkUI';
import { HdsTabs, HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { MaterialEffectHelper, SystemMaterialConfig } from '../../common/material/MaterialEffectHelper';
import { AppDataService } from '../../common/services/AppDataService';
import { HomePage } from '../home/HomePage';
import { FavoritesPage } from '../favorites/FavoritesPage';
import { ExplorePage } from '../explore/ExplorePage';
import { CategoriesPage } from '../categories/CategoriesPage';
import { SysTheme } from '../../common/theme/SysTheme';
import { EXPLORE_SCROLL_TOP_KEY } from '../../common/constants/StartupKeys';

/**
 * 主壳层：HdsNavigation + HdsTabs，API 23 悬浮底栏与沉浸光感材质。
 * 对应 upstream lib/pages/main_page.dart (NaviPane)。
 */
@Component
export struct MainShell {
  @State currentIndex: number = AppDataService.getInstance().settings.initialPage;
  @State pageTitle: Resource = $r('app.string.tab_home');
  @State materialConfig: SystemMaterialConfig = MaterialEffectHelper.getTabsMaterial();
  @State categorySourceKey: string = '';

  aboutToAppear(): void {
    this.syncPageTitle(this.currentIndex);
    MaterialEffectHelper.initialize().then(() => {
      this.materialConfig = MaterialEffectHelper.getTabsMaterial();
    });
  }

  private syncPageTitle(index: number): void {
    switch (index) {
      case 0:
        this.pageTitle = $r('app.string.tab_home');
        break;
      case 1:
        this.pageTitle = $r('app.string.tab_favorites');
        break;
      case 2:
        this.pageTitle = $r('app.string.tab_explore');
        break;
      case 3:
        this.pageTitle = $r('app.string.tab_categories');
        break;
      default:
        this.pageTitle = $r('app.string.tab_home');
        break;
    }
  }

  build() {
    Column() {
      HdsNavigation() {
        HdsTabs({ index: this.currentIndex }) {
          TabContent() {
            HomePage()
          }.tabBar(this.tabItem($r('app.string.tab_home'), 0,
            $r('sys.symbol.house'), $r('sys.symbol.house_fill')))

          TabContent() {
            FavoritesPage()
          }.tabBar(this.tabItem($r('app.string.tab_favorites'), 1,
            $r('sys.symbol.heart'), $r('sys.symbol.heart_fill')))

          TabContent() {
            ExplorePage()
          }.tabBar(this.tabItem($r('app.string.tab_explore'), 2,
            $r('sys.symbol.compass'), $r('sys.symbol.compass_circle_fill')))

          TabContent() {
            CategoriesPage({
              initialSourceKey: this.categorySourceKey
            })
          }.tabBar(this.tabItem($r('app.string.tab_categories'), 3,
            $r('sys.symbol.square_grid_2x2'), $r('sys.symbol.square_fill_grid_2x2')))
        }
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .barFloatingStyle({
          barWidth: { smallWidth: 280, mediumWidth: 360, largeWidth: 420 },
          barBottomMargin: 28,
          gradientMask: { maskColor: '#66000000', maskHeight: 92 },
          barOpacity: 0.92,
          systemMaterialEffect: {
            materialType: this.materialConfig.materialType,
            materialLevel: this.materialConfig.materialLevel
          }
        })
        .onChange((index: number) => {
          this.currentIndex = index;
          this.syncPageTitle(index);
          AppDataService.getInstance().settings.initialPage = index;
          AppDataService.getInstance().save();
        })
        .onTabBarClick((index: number) => {
          if (index === 2 && this.currentIndex === 2) {
            const prev = AppStorage.get<number>(EXPLORE_SCROLL_TOP_KEY) ?? 0;
            AppStorage.setOrCreate(EXPLORE_SCROLL_TOP_KEY, prev + 1);
          }
        })
        .layoutWeight(1)
      }
      .titleBar({
        content: {
          title: { mainTitle: this.pageTitle },
          menu: {
            value: this.currentIndex !== 0 ? [
              {
                content: {
                  icon: $r('sys.symbol.magnifyingglass'),
                  action: () => {
                    router.pushUrl({ url: 'pages/search/SearchPage' });
                  }
                }
              },
              {
                content: {
                  icon: $r('sys.symbol.gearshape'),
                  action: () => {
                    router.pushUrl({ url: 'pages/settings/SettingsPage' });
                  }
                }
              }
            ] : [
              {
                content: {
                  icon: $r('sys.symbol.gearshape'),
                  action: () => {
                    router.pushUrl({ url: 'pages/settings/SettingsPage' });
                  }
                }
              }
            ]
          }
        },
        style: {
          systemMaterialEffect: {
            materialType: this.materialConfig.materialType,
            materialLevel: this.materialConfig.materialLevel
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: true
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  tabItem(label: Resource, index: number, icon: Resource, activeIcon: Resource) {
    Column() {
      SymbolGlyph(index === this.currentIndex ? activeIcon : icon)
        .fontSize(22)
        .fontColor([index === this.currentIndex ? SysTheme.TAB_SELECTED : SysTheme.TAB_NORMAL])
      Text(label)
        .fontSize(11)
        .fontColor(index === this.currentIndex ? SysTheme.EMPHASIZE : SysTheme.FONT_SECONDARY)
        .margin({ top: 4 })
    }
    .justifyContent(FlexAlign.Center)
    .height(56)
  }
}
