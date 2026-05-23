import { promptAction, router } from '@kit.ArkUI';
import { CategoryComicsResult, Comic } from '../../common/models/ComicModels';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { NetworkFavoritesImportService } from '../../common/services/NetworkFavoritesImportService';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';

/**
 * 网络收藏内容区 — 对齐 upstream network_favorites_page.dart
 */
@Component
export struct NetworkFavoritesPanel {
  @Prop @Watch('onSourceKeyChanged') sourceKey: string = '';
  @State comics: Comic[] = [];
  @State page: number = 1;
  @State maxPage: number = 1;
  @State nextToken: string = '';
  @State loading: boolean = false;
  @State error: string = '';
  @State multiFolder: boolean = false;
  @State folderNames: string[] = [];
  @State folderIds: string[] = [];
  @State activeFolderId: string | null = null;
  @State activeFolderTitle: string = '';
  @State showFolderList: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  onSourceKeyChanged(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    this.comics = [];
    this.folderIds = [];
    this.folderNames = [];
    this.nextToken = '';
    this.activeFolderId = null;
    this.error = '';
    const meta = await ComicSourceService.getInstance().getNetworkFavoriteMeta(this.sourceKey);
    this.multiFolder = meta !== null && meta.multiFolder;
    if (this.multiFolder) {
      this.showFolderList = true;
      await this.loadFolders();
    } else {
      this.showFolderList = false;
      await this.loadPage(1, false);
    }
  }

  private async loadFolders(): Promise<void> {
    this.loading = true;
    this.error = '';
    const res = await ComicSourceService.getInstance()
      .loadNetworkFavoriteFolders(this.sourceKey, null);
    this.loading = false;
    if (res.error.length > 0) {
      this.error = res.error;
      return;
    }
    const ids = Object.keys(res.folders);
    this.folderIds = ids;
    this.folderNames = [];
    for (let i = 0; i < ids.length; i++) {
      this.folderNames.push(res.folders[ids[i]]);
    }
  }

  private async loadPage(targetPage: number, append: boolean): Promise<void> {
    if (this.sourceKey.length === 0) {
      return;
    }
    this.loading = true;
    this.error = '';
    let result: CategoryComicsResult;
    if (append && this.nextToken.length > 0) {
      result = await ComicSourceService.getInstance()
        .loadNetworkFavoriteNext(this.sourceKey, this.nextToken, this.activeFolderId);
    } else {
      result = await ComicSourceService.getInstance()
        .loadNetworkFavoriteComics(this.sourceKey, targetPage, this.activeFolderId);
    }
    this.loading = false;
    if (result.error.length > 0) {
      this.error = result.error;
      if (!append) {
        this.comics = [];
      }
      return;
    }
    this.page = targetPage;
    this.maxPage = result.maxPage > 0 ? result.maxPage : 1;
    if (result.next.length > 0) {
      this.nextToken = result.next;
    }
    this.comics = append ? this.comics.concat(result.comics) : result.comics;
  }

  private openComic(comic: Comic): void {
    router.pushUrl({
      url: 'pages/comic/ComicDetailPage',
      params: { comicJson: JSON.stringify(comic) }
    });
  }

  private async confirmRemove(comic: Comic): Promise<void> {
    try {
      const res = await promptAction.showDialog({
        title: '移除收藏',
        message: '从网络收藏中移除此漫画？',
        buttons: [{ text: '取消', color: '#FF999999' }, { text: '确认', color: '#FFE84026' }]
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_e) {
      return;
    }
    const folderId = this.activeFolderId ?? '';
    const err = await ComicSourceService.getInstance().removeNetworkFavoriteComic(
      this.sourceKey,
      comic.id,
      folderId,
      comic.favoriteId ?? null
    );
    if (err.length > 0) {
      promptAction.showToast({ message: err });
      return;
    }
    this.comics = this.comics.filter((c: Comic) => c.id !== comic.id || c.sourceKey !== comic.sourceKey);
    promptAction.showToast({ message: '已移除' });
  }

  private openFolder(index: number): void {
    this.activeFolderId = this.folderIds[index];
    this.activeFolderTitle = this.folderNames[index];
    this.showFolderList = false;
    this.nextToken = '';
    this.loadPage(1, false);
  }

  private async convertToLocal(): Promise<void> {
    try {
      const res = await promptAction.showDialog({
        title: '转本地',
        message: '将当前网络收藏导入为本地收藏夹？已存在的漫画会跳过。',
        buttons: [{ text: '取消', color: '#FF999999' }, { text: '开始', color: '#FF0A59F7' }]
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_e) {
      return;
    }
    const folderId = this.activeFolderId ?? '';
    const folderTitle = this.multiFolder && !this.showFolderList ?
      this.activeFolderTitle : null;
    await NetworkFavoritesImportService.getInstance().importNetworkFolder(
      this.sourceKey,
      9999999,
      folderTitle,
      folderId.length > 0 ? folderId : null
    );
  }

  build() {
    Column() {
      Row() {
        if (this.multiFolder && !this.showFolderList) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(18)
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showFolderList = true;
            this.activeFolderId = null;
            this.comics = [];
          })
          Text(this.activeFolderTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.FONT_PRIMARY)
            .layoutWeight(1)
        } else if (!this.showFolderList || !this.multiFolder) {
          Text('')
            .layoutWeight(1)
        }
        if (!this.showFolderList) {
          Button({ type: ButtonType.Capsule }) {
            Text('转本地')
              .fontSize(13)
          }
          .height(32)
          .margin({ right: 8 })
          .onClick(() => this.convertToLocal())
        }
      }
      .width('100%')
      .padding({ left: 4, right: 8, bottom: 4 })

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
      }

      if (this.loading && this.comics.length === 0 && this.folderIds.length === 0) {
        LoadingProgress().width(40).height(40).margin(24)
      } else if (this.showFolderList && this.multiFolder) {
        if (this.folderIds.length === 0 && !this.loading) {
          Text($r('app.string.network_favorites_empty'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
            .layoutWeight(1)
        } else {
          List() {
            ForEach(this.folderIds, (fid: string, index: number) => {
              ListItem() {
                Row() {
                  SymbolGlyph($r('sys.symbol.folder'))
                    .fontSize(22)
                    .fontColor([SysTheme.EMPHASIZE])
                  Text(this.folderNames[index])
                    .fontSize(16)
                    .fontColor(SysTheme.FONT_PRIMARY)
                    .margin({ left: 12 })
                    .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16)
                    .fontColor([SysTheme.FONT_SECONDARY])
                }
                .width('100%')
                .padding(14)
                .onClick(() => this.openFolder(index))
              }
            }, (fid: string) => fid)
          }
          .layoutWeight(1)
        }
      } else if (this.comics.length === 0 && !this.loading) {
        Text($r('app.string.network_favorites_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.comics, (comic: Comic) => {
            ListItem() {
              Row() {
                ComicListRow({
                  comic: comic,
                  onItemClick: () => this.openComic(comic)
                })
                  .layoutWeight(1)
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(18)
                    .fontColor(['#FFE84026'])
                }
                .width(40)
                .height(40)
                .backgroundColor(Color.Transparent)
                .onClick(() => this.confirmRemove(comic))
              }
              .width('100%')
            }
          }, (c: Comic) => `${c.sourceKey}_${c.id}`)
        }
        .layoutWeight(1)

        if (this.page < this.maxPage || this.nextToken.length > 0) {
          Button(this.loading ? '加载中…' : '加载更多')
            .margin(16)
            .enabled(!this.loading)
            .onClick(() => {
              if (this.nextToken.length > 0) {
                this.loadPage(this.page + 1, true);
              } else {
                this.loadPage(this.page + 1, true);
              }
            })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
