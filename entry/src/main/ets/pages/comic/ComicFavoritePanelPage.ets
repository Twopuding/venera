import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router, promptAction } from '@kit.ArkUI';
import { Comic } from '../../common/models/ComicModels';
import { LocalFavoritesService } from '../../common/services/LocalFavoritesService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { ComicTypeUtil } from '../../common/utils/ComicTypeUtil';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 漫画详情收藏面板 — 对齐 upstream comic_details_page/favorite.dart
 */
@Entry
@Component
struct ComicFavoritePanelPage {
  @State comic: Comic = new Comic();
  @State localFolders: string[] = [];
  @State localAdded: string[] = [];
  @State networkFolders: Record<string, string> = {};
  @State networkAdded: string[] = [];
  @State hasNetwork: boolean = false;
  @State loadingNetwork: boolean = false;
  @State networkBusyId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params['comicJson']) {
      this.comic = JSON.parse(params['comicJson']) as Comic;
    }
    this.refreshLocal();
    this.loadNetwork();
  }

  private async refreshLocal(): Promise<void> {
    const mgr = LocalFavoritesService.getInstance();
    this.localFolders = mgr.folderNames();
    const type = ComicTypeUtil.typeFromSourceKey(this.comic.sourceKey);
    this.localAdded = await mgr.find(this.comic.id, type);
  }

  private async loadNetwork(): Promise<void> {
    const meta = await JsEngineBridge.getInstance().invokeFavoriteMeta(this.comic.sourceKey);
    const logged = ComicSourceService.getInstance().isSourceLogged(this.comic.sourceKey);
    this.hasNetwork = meta !== null && meta.hasAddOrDel && logged;
    if (!this.hasNetwork) {
      return;
    }
    this.loadingNetwork = true;
    const res = await JsEngineBridge.getInstance()
      .invokeFavoriteLoadFolders(this.comic.sourceKey, this.comic.id);
    this.networkFolders = res.folders;
    this.networkAdded = [...res.addedFolderIds];
    if (this.networkAdded.length > 0) {
      this.comic.isFavorite = true;
    }
    this.loadingNetwork = false;
  }

  private async toggleLocalFolder(folder: string, add: boolean): Promise<void> {
    const mgr = LocalFavoritesService.getInstance();
    const type = ComicTypeUtil.typeFromSourceKey(this.comic.sourceKey);
    if (add) {
      await mgr.addComicFromModel(folder, this.comic);
      if (!this.localAdded.includes(folder)) {
        this.localAdded = [...this.localAdded, folder];
      }
    } else {
      await mgr.deleteComicWithId(folder, this.comic.id, type);
      this.localAdded = this.localAdded.filter((f: string) => f !== folder);
    }
  }

  private async toggleNetworkFolder(folderId: string, add: boolean): Promise<void> {
    this.networkBusyId = folderId;
    const err = await JsEngineBridge.getInstance()
      .invokeFavoriteAddOrDel(this.comic.sourceKey, this.comic.id, folderId, add);
    this.networkBusyId = '';
    if (err.length > 0) {
      try {
        promptAction.showToast({ message: err, duration: 2500 });
      } catch (_e) {
        console.warn(`[ComicFavoritePanel] ${err}`);
      }
      return;
    }
    if (add) {
      if (this.networkAdded.indexOf(folderId) < 0) {
        this.networkAdded = [...this.networkAdded, folderId];
      }
    } else {
      this.networkAdded = this.networkAdded.filter((id: string) => id !== folderId);
    }
    try {
      promptAction.showToast({ message: add ? '已添加' : '已移除', duration: 1500 });
    } catch (_e) {
      // ignore
    }
  }

  private async createLocalFolder(): Promise<void> {
    const name = `收藏夹 ${this.localFolders.length + 1}`;
    await LocalFavoritesService.getInstance().createFolder(name);
    await this.refreshLocal();
    await this.toggleLocalFolder(name, true);
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.favorite_action') })

      List() {
        ListItem() {
          Text($r('app.string.favorites_local'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.EMPHASIZE)
            .padding({ left: 16, top: 12, bottom: 8 })
        }

        ForEach(this.localFolders, (folder: string) => {
          ListItem() {
            Row() {
              Text(folder)
                .fontSize(15)
                .layoutWeight(1)
              Text(this.localAdded.indexOf(folder) >= 0 ? '移除' : $r('app.string.add'))
                .fontSize(13)
                .fontColor(this.localAdded.indexOf(folder) >= 0 ? '#FFE53935' : SysTheme.EMPHASIZE)
                .onClick(() => {
                  const added = this.localAdded.indexOf(folder) >= 0;
                  this.toggleLocalFolder(folder, !added);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          }
        }, (folder: string) => folder)

        ListItem() {
          Text($r('app.string.new_favorite_folder'))
            .fontSize(14)
            .fontColor(SysTheme.EMPHASIZE)
            .padding(16)
            .onClick(() => this.createLocalFolder())
        }

        if (this.hasNetwork) {
          ListItem() {
            Text($r('app.string.favorites_network'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(SysTheme.EMPHASIZE)
              .padding({ left: 16, top: 16, bottom: 8 })
          }

          if (this.loadingNetwork) {
            ListItem() {
              LoadingProgress().width(28).height(28).margin(16)
            }
          } else {
            ForEach(Object.keys(this.networkFolders), (folderId: string) => {
              ListItem() {
                Row() {
                  Text(this.networkFolders[folderId])
                    .fontSize(15)
                    .layoutWeight(1)
                  if (this.networkBusyId === folderId) {
                    LoadingProgress().width(24).height(24)
                  } else {
                    Text(this.networkAdded.indexOf(folderId) >= 0 ? '移除' : $r('app.string.add'))
                      .fontSize(13)
                      .fontColor(this.networkAdded.indexOf(folderId) >= 0 ?
                        '#FFE53935' : SysTheme.EMPHASIZE)
                      .onClick(() => {
                        const added = this.networkAdded.indexOf(folderId) >= 0;
                        this.toggleNetworkFolder(folderId, !added);
                      })
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }
            }, (folderId: string) => folderId)

            if (Object.keys(this.networkFolders).length === 0) {
              ListItem() {
                Row() {
                  Text($r('app.string.network_favorite_toggle'))
                    .fontSize(15)
                    .layoutWeight(1)
                  if (this.networkBusyId === '') {
                    Text(this.comic.isFavorite ? '移除' : $r('app.string.add'))
                      .fontSize(13)
                      .fontColor(SysTheme.EMPHASIZE)
                      .onClick(() => {
                        const adding = !(this.comic.isFavorite ?? false);
                        this.toggleNetworkFolder('', adding);
                        this.comic.isFavorite = adding;
                      })
                  } else {
                    LoadingProgress().width(24).height(24)
                  }
                }
                .width('100%')
                .padding(16)
              }
            }
          }
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
