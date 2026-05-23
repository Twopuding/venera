import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { Comic } from '../../common/models/ComicModels';
import { FavoriteItem } from '../../common/models/FavoriteModels';
import { LocalFavoritesService } from '../../common/services/LocalFavoritesService';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ComicListRow } from '../../common/components/ComicListRow';
import { ShellInsets } from '../../common/layout/ShellInsets';
import { SysTheme } from '../../common/theme/SysTheme';
import { NetworkFavoritesPanel } from './NetworkFavoritesPanel';
import { NetworkFavoritesImportService } from '../../common/services/NetworkFavoritesImportService';

/** 收藏 Tab — 对齐 upstream lib/pages/favorites/favorites_page.dart + side_bar.dart */
@Component
export struct FavoritesPage {
  scroller: Scroller = new Scroller();
  @State folders: string[] = [];
  @State networkFolders: string[] = [];
  @State selectedFolder: string = '';
  @State isNetwork: boolean = false;
  @State comics: FavoriteItem[] = [];
  @State wideLayout: boolean = false;
  @State showFolderDrawer: boolean = false;
  @State multiSelectMode: boolean = false;
  @State selectedComicKeys: string[] = [];
  @State showFolderPicker: boolean = false;
  @State pickerMode: string = 'copy';
  @State pickerSelectedFolders: string[] = [];
  @State linkedNetworkSource: string = '';
  @State linkedNetworkFolderId: string = '';
  private refresh = (): void => { this.reload(); };

  private async reloadAsync(): Promise<void> {
    await LocalFavoritesService.getInstance().refreshFolderNames();
    this.folders = LocalFavoritesService.getInstance().folderNames();
    this.networkFolders = await ComicSourceService.getInstance().listEnabledNetworkFavoriteKeys();
    if (this.isNetwork) {
      if (this.selectedFolder.length === 0 ||
        this.networkFolders.indexOf(this.selectedFolder) < 0) {
        if (this.networkFolders.length > 0) {
          this.selectNetworkFolder(this.networkFolders[0]);
        } else {
          this.selectedFolder = '';
        }
      }
      return;
    }
    if (this.selectedFolder.length === 0 && this.folders.length > 0) {
      this.selectedFolder = this.folders[0];
    }
    if (this.selectedFolder.length > 0) {
      this.comics = await LocalFavoritesService.getInstance().getFolderComics(this.selectedFolder);
      if (!this.isNetwork && this.selectedFolder !== LocalFavoritesService.LOCAL_ALL_FOLDER) {
        const linked = await LocalFavoritesService.getInstance().findLinked(this.selectedFolder);
        this.linkedNetworkSource = linked[0] ?? '';
        this.linkedNetworkFolderId = linked[1] ?? '';
      } else {
        this.linkedNetworkSource = '';
        this.linkedNetworkFolderId = '';
      }
    } else {
      this.comics = [];
      this.linkedNetworkSource = '';
      this.linkedNetworkFolderId = '';
    }
  }

  aboutToAppear(): void {
    try {
      const w = display.getDefaultDisplaySync().width;
      this.wideLayout = w >= 720;
    } catch (_e) {
      this.wideLayout = false;
    }
    const app = AppDataService.getInstance();
    this.isNetwork = app.favoriteFolderIsNetwork;
    if (app.favoriteFolderName.length > 0) {
      if (this.isNetwork) {
        this.selectedFolder = app.favoriteFolderName;
      } else if (LocalFavoritesService.getInstance().existsFolder(app.favoriteFolderName)) {
        this.selectedFolder = app.favoriteFolderName;
      }
    }
    LocalFavoritesService.getInstance().onChange(this.refresh);
    AppDataService.getInstance().onSettingsChange(this.refresh);
    this.reloadAsync();
    ComicSourceService.getInstance().getInstalledSources().then(() => {
      this.reloadAsync();
    });
  }

  private reload(): void {
    this.reloadAsync();
  }

  private persistSelection(): void {
    AppDataService.getInstance().favoriteFolderName = this.selectedFolder;
    AppDataService.getInstance().favoriteFolderIsNetwork = this.isNetwork;
    AppDataService.getInstance().save();
  }

  private selectLocalFolder(name: string): void {
    this.isNetwork = false;
    this.selectedFolder = name;
    this.exitMultiSelect();
    this.persistSelection();
    this.showFolderDrawer = false;
    this.reload();
  }

  private comicKey(item: FavoriteItem): string {
    return `${item.type}::${item.id}`;
  }

  private isComicSelected(item: FavoriteItem): boolean {
    return this.selectedComicKeys.indexOf(this.comicKey(item)) >= 0;
  }

  private toggleComicSelection(item: FavoriteItem): void {
    const key = this.comicKey(item);
    if (this.selectedComicKeys.indexOf(key) >= 0) {
      this.selectedComicKeys = this.selectedComicKeys.filter((k: string) => k !== key);
    } else {
      this.selectedComicKeys = this.selectedComicKeys.concat([key]);
    }
    if (this.selectedComicKeys.length === 0) {
      this.multiSelectMode = false;
    } else {
      this.multiSelectMode = true;
    }
  }

  private exitMultiSelect(): void {
    this.multiSelectMode = false;
    this.selectedComicKeys = [];
    this.showFolderPicker = false;
    this.pickerSelectedFolders = [];
  }

  private isAllFolder(): boolean {
    return this.selectedFolder === LocalFavoritesService.LOCAL_ALL_FOLDER;
  }

  private selectedItems(): FavoriteItem[] {
    const out: FavoriteItem[] = [];
    for (let i = 0; i < this.comics.length; i++) {
      if (this.isComicSelected(this.comics[i])) {
        out.push(this.comics[i]);
      }
    }
    return out;
  }

  private selectAllComics(): void {
    const keys: string[] = [];
    for (let i = 0; i < this.comics.length; i++) {
      keys.push(this.comicKey(this.comics[i]));
    }
    this.selectedComicKeys = keys;
    this.multiSelectMode = keys.length > 0;
  }

  private async deleteSelectedComics(): Promise<void> {
    const items = this.selectedItems();
    if (items.length === 0 || this.isAllFolder()) {
      return;
    }
    try {
      const res = await promptAction.showDialog({
        title: '删除',
        message: `从「${this.selectedFolder}」删除 ${items.length} 部漫画？`,
        buttons: [{ text: '取消', color: '#FF999999' }, { text: '删除', color: '#FFE84026' }]
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_e) {
      return;
    }
    await LocalFavoritesService.getInstance().batchDeleteComics(this.selectedFolder, items);
    this.exitMultiSelect();
    this.reload();
  }

  private openFolderPicker(mode: string): void {
    this.pickerMode = mode;
    this.pickerSelectedFolders = [];
    this.showFolderPicker = true;
  }

  private async confirmFolderPicker(): Promise<void> {
    if (this.pickerSelectedFolders.length === 0) {
      return;
    }
    const items = this.selectedItems();
    for (let i = 0; i < this.pickerSelectedFolders.length; i++) {
      const target = this.pickerSelectedFolders[i];
      if (this.pickerMode === 'move') {
        await LocalFavoritesService.getInstance()
          .batchMoveFavorites(this.selectedFolder, target, items);
      } else {
        await LocalFavoritesService.getInstance()
          .batchCopyFavorites(this.selectedFolder, target, items);
      }
    }
    this.showFolderPicker = false;
    this.exitMultiSelect();
    this.reload();
    promptAction.showToast({ message: this.pickerMode === 'move' ? '已移动' : '已复制' });
  }

  private async syncLinkedNetwork(): Promise<void> {
    if (this.linkedNetworkSource.length === 0) {
      return;
    }
    await NetworkFavoritesImportService.getInstance().importNetworkFolder(
      this.linkedNetworkSource,
      3,
      this.selectedFolder,
      this.linkedNetworkFolderId
    );
    this.reload();
  }

  private selectNetworkFolder(key: string): void {
    this.isNetwork = true;
    this.selectedFolder = key;
    this.persistSelection();
    this.showFolderDrawer = false;
    this.comics = [];
  }

  private folderTitle(): string {
    if (this.selectedFolder.length === 0) {
      return '未选择收藏夹';
    }
    if (this.isNetwork) {
      return ComicSourceService.getInstance().getNetworkFavoriteTitle(this.selectedFolder);
    }
    if (this.selectedFolder === LocalFavoritesService.LOCAL_ALL_FOLDER) {
      return '全部漫画';
    }
    return this.selectedFolder;
  }

  private async createFolder(): Promise<void> {
    try {
      const res = await promptAction.showDialog({
        title: '新建收藏夹',
        message: '输入文件夹名称',
        buttons: [{ text: '取消', color: '#FF999999' }, { text: '创建', color: '#FF0A59F7' }]
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_e) {
      return;
    }
    const name = `收藏夹${this.folders.length + 1}`;
    const created = await LocalFavoritesService.getInstance().createFolder(name);
    this.selectLocalFolder(created);
  }

  private favoriteToComic(item: FavoriteItem): Comic {
    const c = new Comic();
    c.id = item.id;
    c.sourceKey = item.sourceKey.length > 0 ? item.sourceKey :
      ComicSourceService.getInstance().getSourceKeyByType(item.type);
    c.title = item.name;
    c.cover = item.coverPath;
    c.subtitle = item.author;
    c.tags = item.tags;
    return c;
  }

  build() {
    Row() {
      if (this.wideLayout || this.showFolderDrawer) {
        this.folderSidebar()
      }
      Column() {
        Row() {
          if (!this.wideLayout) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.line_3_horizontal'))
                .fontSize(20)
            }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showFolderDrawer = !this.showFolderDrawer;
            })
          }
          Text(this.multiSelectMode ?
            `已选 ${this.selectedComicKeys.length}` : this.folderTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(SysTheme.FONT_PRIMARY)
            .layoutWeight(1)
          if (this.multiSelectMode && !this.isNetwork) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(18)
            }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => this.exitMultiSelect())
            if (!this.isAllFolder()) {
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(18)
                  .fontColor(['#FFE84026'])
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.deleteSelectedComics())
            }
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.checkmark_circle'))
                .fontSize(18)
            }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => this.selectAllComics())
          } else if (!this.isNetwork) {
            if (this.linkedNetworkSource.length > 0 && !this.isAllFolder()) {
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(18)
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.syncLinkedNetwork())
            }
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
                this.selectedComicKeys = [];
              }
            })
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(18)
            }
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
            .onClick(() => this.createFolder())
          }
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8 })

        if (this.selectedFolder.length === 0) {
          Column() {
            Text($r('app.string.favorites_pick_folder'))
              .fontColor(SysTheme.FONT_SECONDARY)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.isNetwork) {
          NetworkFavoritesPanel({ sourceKey: this.selectedFolder })
            .layoutWeight(1)
        } else if (this.comics.length === 0) {
          Column() {
            Text($r('app.string.empty_favorites'))
              .fontColor(SysTheme.FONT_SECONDARY)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.comics, (item: FavoriteItem) => {
              ListItem() {
                Row() {
                  if (this.multiSelectMode) {
                    SymbolGlyph(this.isComicSelected(item) ?
                      $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
                      .fontSize(22)
                      .fontColor(this.isComicSelected(item) ?
                        [SysTheme.EMPHASIZE] : [SysTheme.FONT_SECONDARY])
                      .margin({ right: 8 })
                  }
                  ComicListRow({
                    comic: this.favoriteToComic(item),
                    onItemClick: () => {
                      if (this.multiSelectMode) {
                        this.toggleComicSelection(item);
                      } else {
                        router.pushUrl({
                          url: 'pages/comic/ComicDetailPage',
                          params: { comicJson: JSON.stringify(this.favoriteToComic(item)) }
                        });
                      }
                    }
                  })
                    .layoutWeight(1)
                }
                .width('100%')
                .backgroundColor(this.isComicSelected(item) ?
                  SysTheme.BACKGROUND_SECONDARY : Color.Transparent)
                .gesture(
                  LongPressGesture().onAction(() => {
                    if (!this.multiSelectMode) {
                      this.multiSelectMode = true;
                    }
                    if (!this.isComicSelected(item)) {
                      this.toggleComicSelection(item);
                    }
                  })
                )
              }
            }, (item: FavoriteItem) => `${item.type}_${item.id}`)
          }
          .width('100%')
          .layoutWeight(1)

          if (this.multiSelectMode && !this.isAllFolder()) {
            Row({ space: 8 }) {
              Button('复制到…')
                .layoutWeight(1)
                .onClick(() => this.openFolderPicker('copy'))
              Button('移动到…')
                .layoutWeight(1)
                .onClick(() => this.openFolderPicker('move'))
            }
            .width('100%')
            .padding(12)
          }
        }

        if (this.showFolderPicker) {
          this.folderPickerSheet()
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      bottom: ShellInsets.FLOATING_BAR_RESERVE
    })
  }

  @Builder
  folderSidebar() {
    Column() {
      Text($r('app.string.favorites_folders'))
        .fontSize(14)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding({ left: 16, top: 12, bottom: 4 })

      List() {
        ListItem() {
          this.sectionTitle($r('app.string.favorites_local'), false)
        }
        ListItem() {
          this.folderRow(LocalFavoritesService.LOCAL_ALL_FOLDER, '全部漫画', false)
        }
        ForEach(this.folders, (name: string) => {
          ListItem() {
            this.folderRow(name, name, false)
          }
        }, (name: string) => `local_${name}`)

        ListItem() {
          this.sectionTitle($r('app.string.favorites_network'), true)
        }
        ForEach(this.networkFolders, (key: string) => {
          ListItem() {
            this.folderRow(key, ComicSourceService.getInstance().getNetworkFavoriteTitle(key), true)
          }
        }, (key: string) => `net_${key}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width(this.wideLayout ? 256 : '80%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
    .border({ width: { right: 0.6 }, color: '#33000000' })
  }

  @Builder
  sectionTitle(label: Resource, isNetwork: boolean) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(SysTheme.FONT_SECONDARY)
        .layoutWeight(1)
      if (isNetwork) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(16)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.pushUrl({ url: 'pages/favorites/NetworkFavoritesPickerPage' });
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 8, top: 10, bottom: 4 })
  }

  @Builder
  folderPickerSheet() {
    Column() {
      Text(this.pickerMode === 'move' ? '移动到收藏夹' : '复制到收藏夹')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .padding(16)
      List() {
        ForEach(this.folders, (name: string) => {
          if (name !== this.selectedFolder) {
            ListItem() {
              Row() {
                Text(name)
                  .fontSize(15)
                  .layoutWeight(1)
                Checkbox()
                  .select(this.pickerSelectedFolders.indexOf(name) >= 0)
                  .onChange((v: boolean) => {
                    if (v) {
                      if (this.pickerSelectedFolders.indexOf(name) < 0) {
                        this.pickerSelectedFolders = this.pickerSelectedFolders.concat([name]);
                      }
                    } else {
                      this.pickerSelectedFolders =
                        this.pickerSelectedFolders.filter((f: string) => f !== name);
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            }
          }
        }, (name: string) => `pick_${name}`)
      }
      .layoutWeight(1)
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .onClick(() => {
            this.showFolderPicker = false;
          })
        Button('确定')
          .layoutWeight(1)
          .onClick(() => this.confirmFolderPicker())
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('50%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '50%' })
  }

  @Builder
  folderRow(folderKey: string, label: string, network: boolean) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.selectedFolder === folderKey && this.isNetwork === network ?
          SysTheme.EMPHASIZE : SysTheme.FONT_PRIMARY)
        .layoutWeight(1)
      if (!network && folderKey !== LocalFavoritesService.LOCAL_ALL_FOLDER) {
        Text(`${LocalFavoritesService.getInstance().folderComicsCount(folderKey)}`)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.selectedFolder === folderKey && this.isNetwork === network ?
      SysTheme.BACKGROUND_PRIMARY : Color.Transparent)
    .onClick(() => {
      if (network) {
        this.selectNetworkFolder(folderKey);
      } else {
        this.selectLocalFolder(folderKey);
      }
    })
  }
}
