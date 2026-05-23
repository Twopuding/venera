import { router } from '@kit.ArkUI';
import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { ImageFavorite, ImageFavoritesComic } from '../../common/models/ImageFavoriteModels';
import { ImageFavoriteService } from '../../common/services/ImageFavoriteService';
import { ImageFavoriteImageUtil } from '../../common/utils/ImageFavoriteImageUtil';
import { SysTheme } from '../../common/theme/SysTheme';

/**
 * 图片收藏大图浏览 — 对齐 upstream image_favorites_photo_view.dart
 */
@Entry
@Component
struct ImageFavoritesPhotoViewPage {
  @State comic: ImageFavoritesComic | null = null;
  @State images: ImageFavorite[] = [];
  @State paths: string[] = [];
  @State currentIndex: number = 0;
  @State showBar: boolean = false;
  @State loading: boolean = true;
  private sourceKey: string = '';
  private comicId: string = '';
  private startKey: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, Object>;
    this.sourceKey = (p['sourceKey'] as string) ?? '';
    this.comicId = (p['comicId'] as string) ?? '';
    this.startKey = (p['startKey'] as string) ?? '';
    this.loadAsync();
  }

  private async loadAsync(): Promise<void> {
    this.loading = true;
    const comic = await ImageFavoriteService.getInstance().find(this.comicId, this.sourceKey);
    if (!comic) {
      this.loading = false;
      return;
    }
    this.comic = comic;
    this.images = comic.images;
    let start = 0;
    for (let i = 0; i < this.images.length; i++) {
      if (ImageFavoriteImageUtil.selectionKey(this.images[i]) === this.startKey) {
        start = i;
        break;
      }
    }
    this.currentIndex = start;
    this.paths = await ImageFavoriteImageUtil.resolvePaths(this.images);
    this.loading = false;
  }

  private pageLabel(): string {
    return `${this.currentIndex + 1}/${this.images.length}`;
  }

  private openReader(): void {
    if (!this.comic || this.currentIndex >= this.images.length) {
      return;
    }
    const img = this.images[this.currentIndex];
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: this.comic.id,
        sourceKey: this.comic.sourceKey,
        title: this.comic.title,
        chapterId: img.eid,
        pageIndex: String(img.page)
      }
    });
  }

  build() {
    Stack() {
      if (this.loading) {
        LoadingProgress().width(48).height(48)
      } else if (this.images.length === 0) {
        Text('无图片')
          .fontColor(SysTheme.FONT_SECONDARY)
      } else {
        Swiper() {
          ForEach(this.paths, (path: string, index: number) => {
            if (path.length > 0) {
              Image(path.startsWith('file://') ? path : `file://${path}`)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
                .backgroundColor('#FF000000')
            } else {
              Column() {
                Text('加载失败')
                  .fontColor(SysTheme.FONT_SECONDARY)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#FF000000')
            }
          }, (path: string, index: number) => `${index}_${path}`)
        }
        .index(this.currentIndex)
        .indicator(false)
        .loop(false)
        .onChange((idx: number) => {
          this.currentIndex = idx;
        })
        .onClick(() => {
          this.showBar = !this.showBar;
        })
      }

      Text(this.pageLabel())
        .fontSize(14)
        .fontColor(Color.White)
        .padding(8)
        .backgroundColor('#66000000')
        .borderRadius(8)
        .position({ x: '50%', y: '92%' })
        .markAnchor({ x: '50%', y: '50%' })

      if (this.showBar) {
        Column() {
          Row() {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(20)
                .fontColor([Color.White])
            }
            .width(40)
            .height(40)
            .backgroundColor('#44000000')
            .onClick(() => router.back())

            Text(this.comic?.title ?? '')
              .fontSize(18)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8, right: 8 })

            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.book'))
                .fontSize(18)
                .fontColor([Color.White])
            }
            .width(40)
            .height(40)
            .backgroundColor('#44000000')
            .onClick(() => this.openReader())
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        }
        .width('100%')
        .backgroundColor('#B3000000')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FF000000')
    .padding(SafeAreaInsets.pagePadding())
  }
}
