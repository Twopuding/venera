import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 关注更新 — 对齐 upstream lib/pages/follow_updates_page.dart（占位，待本地收藏夹与更新检测）
 */
@Entry
@Component
struct FollowUpdatesPage {
  build() {
    Column() {
        SecondaryPageHeader({ title: $r('app.string.follow_updates') })

        Text($r('app.string.follow_updates_page_hint'))
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
