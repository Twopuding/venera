import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 图片收藏 — 对齐 upstream lib/pages/image_favorites_page/（占位，待 ImageFavoriteManager）
 */
@Entry
@Component
struct ImageFavoritesPage {
  build() {
    Column() {
        SecondaryPageHeader({ title: $r('app.string.image_favorites') })

        Text($r('app.string.image_favorites_page_hint'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 16, right: 16 })
          .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
