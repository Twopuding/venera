/**
 * 漫画块收藏/历史角标 — 对齐 upstream lib/components/comic.dart ComicTile.build Stack
 */

@Component
struct ReadingHistoryBadge {
  @Prop page: number = 1;
  @Prop maxPage: number = 0;

  build() {
    if (this.maxPage > 0 && this.page >= this.maxPage) {
      Column() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor(['#FFFFFFFF'])
      }
      .height(24)
      .constraintSize({ minWidth: 24 })
      .padding({ left: 4, right: 4 })
      .backgroundColor('#E60096F3')
      .justifyContent(FlexAlign.Center)
    } else if (this.maxPage <= 0) {
      Column() {
        Text(`${this.page}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFFFF')
      }
      .height(24)
      .constraintSize({ minWidth: 24 })
      .padding({ left: 4, right: 4 })
      .backgroundColor('#E60096F3')
      .justifyContent(FlexAlign.Center)
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        Text(`${this.page}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFFFF')
        Text(`/${this.maxPage}`)
          .fontSize(8)
          .fontColor('#FFFFFFFF')
          .align(Alignment.BottomEnd)
          .margin({ right: 2, bottom: 1 })
      }
      .height(24)
      .constraintSize({ minWidth: 24 })
      .padding({ left: 4, right: 4 })
      .backgroundColor('#E60096F3')
    }
  }
}

@Component
export struct ComicTileStatusOverlay {
  @Prop isFavorite: boolean = false;
  @Prop historyPage: number = 0;
  @Prop historyMaxPage: number = 0;
  /** brief 网格 6，列表行封面约 4 */
  @Prop insetLeft: number = 6;

  build() {
    Row() {
      if (this.isFavorite) {
        Column() {
          SymbolGlyph($r('sys.symbol.bookmark_fill'))
            .fontSize(16)
            .fontColor(['#FFFFFFFF'])
        }
        .width(24)
        .height(24)
        .backgroundColor('#FF4CAF50')
        .justifyContent(FlexAlign.Center)
      }
      if (this.historyPage > 0) {
        ReadingHistoryBadge({
          page: this.historyPage,
          maxPage: this.historyMaxPage
        })
      }
    }
    .height(24)
    .borderRadius(4)
    .clip(true)
    .position({ x: this.insetLeft, y: 8 })
  }
}
