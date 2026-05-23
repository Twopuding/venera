import { SysTheme } from '../theme/SysTheme';

/** 首页分区卡片 — 对齐 upstream home_page 各 Section 外框 */
@Component
export struct HomeSectionCard {
  @Prop title: Resource = $r('app.string.history');
  @Prop count: number = 0;
  onHeaderClick?: () => void;
  @BuilderParam footer: () => void = this.emptyFooter;
  @BuilderParam body: () => void = this.emptyBody;

  @Builder
  emptyBody() {
  }

  @Builder
  emptyFooter() {
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
        if (this.count > 0) {
          Text(`${this.count}`)
            .fontSize(12)
            .fontColor(SysTheme.FONT_PRIMARY)
            .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(8)
            .margin({ left: 8 })
        }
        Blank().layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([SysTheme.FONT_SECONDARY])
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        if (this.onHeaderClick) {
          this.onHeaderClick();
        }
      })

      this.body()

      this.footer()
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 8 })
    .border({
      width: 0.6,
      color: '#33000000',
      radius: 8
    })
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
