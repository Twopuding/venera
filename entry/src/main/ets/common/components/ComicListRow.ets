import { Comic } from '../models/ComicModels';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';
import { TagTranslationService } from '../services/TagTranslationService';
import { SysTheme } from '../theme/SysTheme';

/** 漫画列表行（封面 + 标题），搜索/分类/收藏复用 */
@Component
export struct ComicListRow {
  @Prop comic: Comic = new Comic();
  onItemClick?: () => void;
  @State coverSrc: string = '';
  @State displayTitle: string = '';
  @State displaySubtitle: string = '';

  aboutToAppear(): void {
    this.displayTitle = TagTranslationService.translateTagLine(this.comic.title);
    this.displaySubtitle = this.comic.subtitle ?
      TagTranslationService.translateTagLine(this.comic.subtitle) : '';
    this.resolveCover();
  }

  private async resolveCover(): Promise<void> {
    if (this.comic.cover.length === 0) {
      this.coverSrc = '';
      return;
    }
    this.coverSrc = ImageCacheUtil.resolveSync(this.comic.cover);
    if (ImageCacheUtil.isRemoteUrl(this.comic.cover) && this.coverSrc === this.comic.cover) {
      this.coverSrc = await ImageCacheUtil.ensureCached(this.comic.cover);
    }
  }

  build() {
    Row({ space: 12 }) {
      if (this.coverSrc.length > 0) {
        Image(this.coverSrc)
          .width(52)
          .height(72)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      } else {
        Column()
          .width(52)
          .height(72)
          .borderRadius(6)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      }
      Column() {
        Text(this.displayTitle.length > 0 ? this.displayTitle : this.comic.title)
          .fontSize(15)
          .fontColor(SysTheme.FONT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.comic.sourceKey.length > 0) {
          Text(this.comic.sourceKey)
            .fontSize(11)
            .fontColor(SysTheme.FONT_SECONDARY)
            .margin({ top: 4 })
        }
        if (this.comic.subtitle && this.comic.subtitle.length > 0) {
          Text(this.displaySubtitle.length > 0 ? this.displaySubtitle : this.comic.subtitle)
            .fontSize(11)
            .fontColor(SysTheme.FONT_SECONDARY)
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}
