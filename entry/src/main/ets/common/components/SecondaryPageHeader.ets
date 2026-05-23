import { router } from '@kit.ArkUI';
import { SysTheme } from '../theme/SysTheme';

/**
 * 二级页顶栏：左侧返回（系统 chevron），标题居中区域展开。
 * 对齐上游 AppBar 返回 + 鸿蒙 Navigation 交互，不在底部放置返回按钮。
 */
@Component
export struct SecondaryPageHeader {
  title: ResourceStr = '';
  @BuilderParam trailing: () => void = this.emptyTrailing;

  @Builder
  emptyTrailing() {
  }

  build() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([SysTheme.FONT_PRIMARY])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .borderRadius(20)
      .onClick(() => {
        router.back();
      })

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      this.trailing()
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
  }
}
