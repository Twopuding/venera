import { router } from '@kit.ArkUI';
import { FavoritesService } from '../../common/services/FavoritesService';
import { Comic } from '../../common/models/ComicModels';
import { ComicListRow } from '../../common/components/ComicListRow';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';

/** 收藏 — 对应 upstream lib/pages/favorites/favorites_page.dart */
@Component
export struct FavoritesPage {
  scroller: Scroller = new Scroller();
  @State comics: Comic[] = [];

  aboutToAppear(): void {
    this.comics = FavoritesService.getInstance().getComics();
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        if (this.comics.length === 0) {
          Column() {
            Text($r('app.string.empty_favorites'))
              .fontColor(SysTheme.FONT_SECONDARY)
          }
          .width('100%')
          .constraintSize({ minHeight: 320 })
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.comics, (comic: Comic) => {
              ListItem() {
                ComicListRow({
                  comic: comic,
                  onItemClick: () => {
                    router.pushUrl({
                      url: 'pages/comic/ComicDetailPage',
                      params: { comicJson: JSON.stringify(comic) }
                    });
                  }
                })
              }
            }, (comic: Comic) => `${comic.sourceKey}_${comic.id}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({
        left: 0,
        right: 0,
        top: 8,
        bottom: ShellInsets.FLOATING_BAR_RESERVE
      })
    }
    .clipContent(ContentClipMode.SAFE_AREA)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
