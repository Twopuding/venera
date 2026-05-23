import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { ComicComment } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { BlockedWordsUtil } from '../../common/utils/BlockedWordsUtil';

/**
 * 漫画评论列表 — 对齐 upstream comments_page.dart（简化全屏列表）
 */
@Entry
@Component
struct ComicCommentsPage {
  @State comments: ComicComment[] = [];
  @State title: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? '';
    const raw = params['commentsJson'] ?? '[]';
    let parsed: ComicComment[] = [];
    try {
      parsed = JSON.parse(raw) as ComicComment[];
    } catch (_e) {
      parsed = [];
    }
    this.comments = parsed.filter((c: ComicComment) =>
      !BlockedWordsUtil.isCommentBlocked(c.content));
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.title.length > 0 ? this.title : $r('app.string.comments')
      })

      if (this.comments.length === 0) {
        Text($r('app.string.comments_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(24)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.comments, (c: ComicComment) => {
            ListItem() {
              Column() {
                Row() {
                  if (c.avatar.length > 0) {
                    Image(c.avatar)
                      .width(32)
                      .height(32)
                      .borderRadius(16)
                      .margin({ right: 8 })
                  }
                  Column() {
                    Text(c.userName.length > 0 ? c.userName : '匿名')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(SysTheme.FONT_PRIMARY)
                    if (c.time.length > 0) {
                      Text(c.time)
                        .fontSize(11)
                        .fontColor(SysTheme.FONT_SECONDARY)
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .alignItems(VerticalAlign.Top)
                Text(c.content)
                  .fontSize(14)
                  .fontColor(SysTheme.FONT_SECONDARY)
                  .margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
            }
          }, (c: ComicComment) => c.id.length > 0 ? c.id : `${c.userName}_${c.time}`)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
