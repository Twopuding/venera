import { Comic } from '../models/ComicModels';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';
import { TagTranslationService } from '../services/TagTranslationService';
import { SysTheme } from '../theme/SysTheme';
import { ComicTileStatusOverlay } from './ComicTileStatusOverlay';
import {
  comicTileStatusVisible,
  loadComicTileStatus
} from '../utils/ComicTileStatusUtil';
import { LocalFavoritesService } from '../services/LocalFavoritesService';
import { HistoryService } from '../services/HistoryService';

/**
 * 探索/收藏网格漫画块 — 对齐上游 SliverGridComics（detailed 模式）+ ComicTile 角标
 */
@Component
export struct ComicGridTile {
  @Prop comic: Comic = new Comic();
  @Prop tileScale: number = 1.0;
  @Prop briefMode: boolean = false;
  onItemClick?: () => void;
  @State coverSrc: string = '';
  @State displayTitle: string = '';
  @State tileIsFavorite: boolean = false;
  @State tileHistoryPage: number = 0;
  @State tileHistoryMaxPage: number = 0;
  private tileStatusHandler: () => void = () => {
    this.refreshTileStatus();
  };

  aboutToAppear(): void {
    this.displayTitle = TagTranslationService.translateTagLine(this.comic.title);
    this.resolveCover();
    this.refreshTileStatus();
    LocalFavoritesService.getInstance().onChange(this.tileStatusHandler);
    HistoryService.getInstance().onChange(this.tileStatusHandler);
  }

  private refreshTileStatus(): void {
    loadComicTileStatus(this.comic.id, this.comic.sourceKey).then((status) => {
      this.tileIsFavorite = status.isFavorite;
      this.tileHistoryPage = status.historyPage;
      this.tileHistoryMaxPage = status.historyMaxPage;
    });
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

  @Builder
  coverWithBadges() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.coverSrc.length > 0) {
        Image(this.coverSrc)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      }
      if (comicTileStatusVisible({
        isFavorite: this.tileIsFavorite,
        historyPage: this.tileHistoryPage,
        historyMaxPage: this.tileHistoryMaxPage
      })) {
        ComicTileStatusOverlay({
          isFavorite: this.tileIsFavorite,
          historyPage: this.tileHistoryPage,
          historyMaxPage: this.tileHistoryMaxPage,
          insetLeft: 6
        })
      }
    }
    .width('100%')
    .aspectRatio(0.72)
    .borderRadius(6)
    .clip(true)
  }

  build() {
    Column() {
      this.coverWithBadges()
      if (!this.briefMode) {
        Text(this.displayTitle.length > 0 ? this.displayTitle : this.comic.title)
          .fontSize(12)
          .fontColor(SysTheme.FONT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .scale({ x: this.tileScale, y: this.tileScale })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}
