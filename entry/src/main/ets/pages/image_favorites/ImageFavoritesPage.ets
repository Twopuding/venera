import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router, promptAction } from '@kit.ArkUI';
import { Comic } from '../../common/models/ComicModels';
import {
  IMAGE_FAVORITE_FIRST_PAGE,
  ImageFavorite,
  ImageFavoritesComic
} from '../../common/models/ImageFavoriteModels';
import { ImageFavoriteService } from '../../common/services/ImageFavoriteService';
import { ImageFavoriteImageUtil } from '../../common/utils/ImageFavoriteImageUtil';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 图片收藏 — 对齐 upstream lib/pages/image_favorites_page/image_favorites_page.dart
 */
@Entry
@Component
struct ImageFavoritesPage {
  @State comics: ImageFavoritesComic[] = [];
  @State keyword: string = '';
  @State searchMode: boolean = false;
  @State multiSelectMode: boolean = false;
  @State selectedKeys: string[] = [];
  @State thumbPaths: Record<string, string> = {};
  private refresh = (): void => { this.loadAsync(); };

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, Object> | undefined;
    const initial = (p?.['keyword'] as string) ?? '';
    if (initial.length > 0) {
      this.keyword = initial;
      this.searchMode = true;
    }
    ImageFavoriteService.getInstance().onChange(this.refresh);
    this.loadAsync();
  }

  private load(): void {
    this.loadAsync();
  }

  private async loadAsync(): Promise<void> {
    if (this.searchMode && this.keyword.trim().length > 0) {
      this.comics = await ImageFavoriteService.getInstance().search(this.keyword);
    } else {
      this.comics = await ImageFavoriteService.getInstance().getAll();
    }
    this.comics.sort((a: ImageFavoritesComic, b: ImageFavoritesComic) =>
      a.title.localeCompare(b.title));
    await this.prefetchThumbs();
  }

  private async prefetchThumbs(): Promise<void> {
    const map: Record<string, string> = {};
    for (let i = 0; i < this.comics.length; i++) {
      const imgs = this.comics[i].images;
      for (let j = 0; j < imgs.length; j++) {
        const key = ImageFavoriteImageUtil.selectionKey(imgs[j]);
        if (map[key] === undefined) {
          map[key] = await ImageFavoriteImageUtil.resolvePath(imgs[j]);
        }
      }
    }
    this.thumbPaths = map;
  }

  private isSelected(img: ImageFavorite): boolean {
    const key = ImageFavoriteImageUtil.selectionKey(img);
    return this.selectedKeys.indexOf(key) >= 0;
  }

  private toggleSelected(img: ImageFavorite): void {
    const key = ImageFavoriteImageUtil.selectionKey(img);
    const idx = this.selectedKeys.indexOf(key);
    if (idx >= 0) {
      this.selectedKeys = this.selectedKeys.filter((k: string) => k !== key);
    } else {
      this.selectedKeys = this.selectedKeys.concat([key]);
    }
    if (this.selectedKeys.length === 0) {
      this.multiSelectMode = false;
    } else {
      this.multiSelectMode = true;
    }
  }

  private selectAll(): void {
    const keys: string[] = [];
    for (let i = 0; i < this.comics.length; i++) {
      const imgs = this.comics[i].images;
      for (let j = 0; j < imgs.length; j++) {
        keys.push(ImageFavoriteImageUtil.selectionKey(imgs[j]));
      }
    }
    this.selectedKeys = keys;
    this.multiSelectMode = keys.length > 0;
  }

  private deselectAll(): void {
    this.selectedKeys = [];
    this.multiSelectMode = false;
  }

  private exitMultiSelect(): void {
    this.multiSelectMode = false;
    this.selectedKeys = [];
  }

  private async deleteSelected(): Promise<void> {
    if (this.selectedKeys.length === 0) {
      return;
    }
    try {
      const res = await promptAction.showDialog({
        title: '删除',
        message: `删除 ${this.selectedKeys.length} 张图片收藏？`,
        buttons: [{ text: '取消', color: '#FF999999' }, { text: '删除', color: '#FFE84026' }]
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_e) {
      return;
    }
    const toDelete: ImageFavorite[] = [];
    for (let i = 0; i < this.comics.length; i++) {
      const imgs = this.comics[i].images;
      for (let j = 0; j < imgs.length; j++) {
        if (this.isSelected(imgs[j])) {
          toDelete.push(imgs[j]);
        }
      }
    }
    await ImageFavoriteService.getInstance().deleteImageFavorite(toDelete);
    this.exitMultiSelect();
    promptAction.showToast({ message: '已删除' });
  }

  private toComic(item: ImageFavoritesComic): Comic {
    const c = new Comic();
    c.id = item.id;
    c.sourceKey = item.sourceKey;
    c.title = item.title;
    c.subtitle = item.subTitle.length > 0 ? item.subTitle : item.author;
    return c;
  }

  private formatDate(ms: number): string {
    const d = new Date(ms);
    const y = d.getFullYear();
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  private openPhotoView(comic: ImageFavoritesComic, img: ImageFavorite): void {
    router.pushUrl({
      url: 'pages/image_favorites/ImageFavoritesPhotoViewPage',
      params: {
        sourceKey: comic.sourceKey,
        comicId: comic.id,
        startKey: ImageFavoriteImageUtil.selectionKey(img)
      }
    });
  }

  private openReader(comic: ImageFavoritesComic, img: ImageFavorite): void {
    router.pushUrl({
      url: 'pages/reader/ReaderPage',
      params: {
        comicId: comic.id,
        sourceKey: comic.sourceKey,
        title: comic.title,
        chapterId: img.eid,
        pageIndex: String(img.page)
      }
    });
  }

  private thumbUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    if (path.startsWith('file://') || path.startsWith('http')) {
      return path;
    }
    return `file://${path}`;
  }

  private pageLabel(img: ImageFavorite): string {
    if (img.page === IMAGE_FAVORITE_FIRST_PAGE) {
      return `${img.epName} 封面`;
    }
    return `${img.page}`;
  }

  build() {
    Column() {
      if (this.multiSelectMode) {
        SecondaryPageHeader({
          title: `${this.selectedKeys.length}`,
          trailing: () => {
            this.multiSelectTrailing()
          }
        })
      } else if (this.searchMode) {
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18)
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.searchMode = false;
            this.keyword = '';
            this.load();
          })
          TextInput({ placeholder: '搜索', text: this.keyword })
            .layoutWeight(1)
            .height(40)
            .onChange((v: string) => {
              this.keyword = v;
              this.load();
            })
        }
        .width('100%')
        .padding({ left: 8, right: 16 })
        .height(56)
      } else {
        SecondaryPageHeader({
          title: $r('app.string.image_favorites'),
          trailing: () => {
            this.normalTrailing()
          }
        })
      }

      if (this.comics.length === 0) {
        Text($r('app.string.image_favorites_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.comics, (item: ImageFavoritesComic) => {
            ListItem() {
              this.comicCard(item)
            }
          }, (item: ImageFavoritesComic) => `${item.sourceKey}_${item.id}`)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  normalTrailing() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.searchMode = true;
      })
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.checkmark_square'))
          .fontSize(18)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.multiSelectMode = !this.multiSelectMode;
        if (!this.multiSelectMode) {
          this.selectedKeys = [];
        }
      })
    }
  }

  @Builder
  multiSelectTrailing() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.selectAll())
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.circle'))
          .fontSize(18)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.deselectAll())
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(18)
          .fontColor(['#FFE84026'])
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.deleteSelected())
    }
  }

  @Builder
  comicCard(item: ImageFavoritesComic) {
    Column() {
      Row() {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`${item.imageCount}/${item.maxPageFromEp}`)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
          .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })
      .onClick(() => {
        if (this.multiSelectMode) {
          for (let i = 0; i < item.images.length; i++) {
            this.toggleSelected(item.images[i]);
          }
        } else if (item.sourceKey.length > 0) {
          router.pushUrl({
            url: 'pages/comic/ComicDetailPage',
            params: { comicJson: JSON.stringify(this.toComic(item)) }
          });
        }
      })

      Scroll() {
        Row() {
          ForEach(item.images, (img: ImageFavorite) => {
            Column() {
              if ((this.thumbPaths[ImageFavoriteImageUtil.selectionKey(img)] ?? '').length > 0) {
                Image(this.thumbUri(this.thumbPaths[ImageFavoriteImageUtil.selectionKey(img)]))
                  .width(96)
                  .height(128)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
              } else {
                Column()
                  .width(96)
                  .height(128)
                  .borderRadius(8)
                  .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
              }
              Text(this.pageLabel(img))
                .fontSize(10)
                .fontColor(SysTheme.FONT_SECONDARY)
                .maxLines(1)
                .margin({ top: 2 })
            }
            .width(104)
            .padding(4)
            .backgroundColor(this.isSelected(img) ? SysTheme.EMPHASIZE : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              if (this.multiSelectMode) {
                this.toggleSelected(img);
              } else {
                this.openReader(item, img);
              }
            })
            .gesture(
              LongPressGesture().onAction(() => {
                this.openPhotoView(item, img);
              })
            )
          }, (img: ImageFavorite) => ImageFavoriteImageUtil.selectionKey(img))
        }
        .padding({ left: 8, right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(150)

      Row() {
        Text(`${this.formatDate(item.time)} | ${ComicSourceService.getInstance().getSourceByKey(item.sourceKey)?.name ?? item.sourceKey}`)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .maxLines(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })
    }
    .width('100%')
    .margin({ left: 8, right: 8, top: 8, bottom: 4 })
    .borderRadius(8)
    .border({ width: 0.6, color: '#33000000' })
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
  }
}
