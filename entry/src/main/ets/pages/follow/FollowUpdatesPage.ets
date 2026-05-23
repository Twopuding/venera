import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Comic } from '../../common/models/ComicModels';
import { FavoriteItemWithUpdateInfo } from '../../common/models/FavoriteModels';
import { LocalFavoritesService } from '../../common/services/LocalFavoritesService';
import { FollowUpdatesService, UpdateProgress } from '../../common/services/FollowUpdatesService';
import { AppDataService } from '../../common/services/AppDataService';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ComicListRow } from '../../common/components/ComicListRow';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 关注更新 — 对齐 upstream lib/pages/follow_updates_page.dart
 */
@Entry
@Component
struct FollowUpdatesPage {
  @State folder: string = '';
  @State allComics: FavoriteItemWithUpdateInfo[] = [];
  @State updatedComics: FavoriteItemWithUpdateInfo[] = [];
  @State checking: boolean = false;
  @State checkProgress: number = 0;
  @State showFolderPicker: boolean = false;
  @State pickerFolders: string[] = [];
  private refresh = (): void => { this.loadComicsAsync(); };

  aboutToAppear(): void {
    this.folder = AppDataService.getInstance().settings.followUpdatesFolder;
    this.loadComicsAsync();
    FollowUpdatesService.getInstance().onChange(this.refresh);
    LocalFavoritesService.getInstance().onChange(this.refresh);
    ComicSourceService.getInstance().getInstalledSources();
  }

  private loadComics(): void {
    this.loadComicsAsync();
  }

  private async loadComicsAsync(): Promise<void> {
    this.folder = AppDataService.getInstance().settings.followUpdatesFolder;
    if (this.folder.length === 0) {
      this.allComics = [];
      this.updatedComics = [];
      return;
    }
    this.allComics = await LocalFavoritesService.getInstance().getComicsWithUpdatesInfo(this.folder);
    this.sortComics();
    this.updatedComics = this.allComics.filter((c: FavoriteItemWithUpdateInfo) => c.hasNewUpdate);
  }

  private sortComics(): void {
    this.allComics.sort((a: FavoriteItemWithUpdateInfo, b: FavoriteItemWithUpdateInfo) => {
      if (!a.updateTime && !b.updateTime) {
        return 0;
      }
      if (!a.updateTime) {
        return 1;
      }
      if (!b.updateTime) {
        return -1;
      }
      return b.updateTime.localeCompare(a.updateTime);
    });
  }

  private itemToComic(item: FavoriteItemWithUpdateInfo): Comic {
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

  private showFolderSelector(): void {
    const folders = LocalFavoritesService.getInstance().folderNames();
    if (folders.length === 0) {
      try {
        promptAction.showToast({ message: '暂无收藏夹，请先在收藏 Tab 创建', duration: 2000 });
      } catch (_e) {
        // ignore
      }
      return;
    }
    this.pickerFolders = folders;
    this.showFolderPicker = true;
  }

  private async disableFollow(): Promise<void> {
    AppDataService.getInstance().settings.followUpdatesFolder = '';
    await AppDataService.getInstance().save();
    this.showFolderPicker = false;
    this.loadComics();
  }

  private async setFolder(name: string): Promise<void> {
    await LocalFavoritesService.getInstance().prepareTableForFollowUpdates(name, true);
    AppDataService.getInstance().settings.followUpdatesFolder = name;
    await AppDataService.getInstance().save();
    this.folder = name;
    const count = await LocalFavoritesService.getInstance().count(name);
    if (count > 0) {
      await this.checkNow();
    } else {
      this.loadComics();
    }
  }

  private async checkNow(): Promise<void> {
    if (this.folder.length === 0 || this.checking) {
      return;
    }
    this.checking = true;
    this.checkProgress = 0;
    FollowUpdatesService.getInstance().cancelChecking();
    await FollowUpdatesService.getInstance().updateFolder(this.folder, true, (p: UpdateProgress) => {
      this.checkProgress = p.total > 0 ? Math.floor((p.current / p.total) * 100) : 0;
    });
    this.checking = false;
    this.loadComics();
  }

  private async markAllRead(): Promise<void> {
    for (let i = 0; i < this.updatedComics.length; i++) {
      await LocalFavoritesService.getInstance().markAsRead(this.updatedComics[i].id, this.updatedComics[i].type);
    }
    await this.loadComicsAsync();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.follow_updates') })

      Scroll() {
        Column() {
          if (this.folder.length === 0) {
            this.configCard(true)
          } else {
            this.configCard(false)
          }

          if (this.showFolderPicker) {
            Column() {
              Text('选择收藏夹')
                .fontSize(14)
                .fontColor(SysTheme.FONT_SECONDARY)
                .margin({ bottom: 8 })
              ForEach(this.pickerFolders, (name: string) => {
                Button(name)
                  .type(ButtonType.Capsule)
                  .width('100%')
                  .margin({ bottom: 6 })
                  .onClick(() => {
                    this.showFolderPicker = false;
                    this.setFolder(name);
                  })
              }, (name: string) => name)
              if (this.folder.length > 0) {
                Button('关闭关注更新')
                  .type(ButtonType.Capsule)
                  .width('100%')
                  .fontColor('#FFE53935')
                  .onClick(() => this.disableFollow())
              }
              Button('取消')
                .type(ButtonType.Capsule)
                .width('100%')
                .margin({ top: 4 })
                .onClick(() => {
                  this.showFolderPicker = false;
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
          }

          Row() {
            Text($r('app.string.follow_updates_section'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Blank()
            if (this.updatedComics.length > 0) {
              Button('全部标为已读')
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .onClick(() => this.markAllRead())
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

          if (this.updatedComics.length === 0) {
            Text($r('app.string.follow_updates_none'))
              .fontSize(14)
              .fontColor(SysTheme.FONT_SECONDARY)
              .padding({ left: 16, right: 16, bottom: 8 })
          } else {
            ForEach(this.updatedComics, (item: FavoriteItemWithUpdateInfo) => {
              ComicListRow({
                comic: this.itemToComic(item),
                onItemClick: () => {
                  router.pushUrl({
                    url: 'pages/comic/ComicDetailPage',
                    params: { comicJson: JSON.stringify(this.itemToComic(item)) }
                  });
                }
              })
            }, (item: FavoriteItemWithUpdateInfo) => `u_${item.type}_${item.id}`)
          }

          Text($r('app.string.follow_updates_all'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })
            .width('100%')

          ForEach(this.allComics, (item: FavoriteItemWithUpdateInfo) => {
            ComicListRow({
              comic: this.itemToComic(item),
              onItemClick: () => {
                router.pushUrl({
                  url: 'pages/comic/ComicDetailPage',
                  params: { comicJson: JSON.stringify(this.itemToComic(item)) }
                });
              }
            })
          }, (item: FavoriteItemWithUpdateInfo) => `a_${item.type}_${item.id}`)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      if (this.checking) {
        Row() {
          LoadingProgress().width(24).height(24)
          Text(`正在检查更新 ${this.checkProgress}%`)
            .fontSize(13)
            .margin({ left: 8 })
        }
        .padding(12)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  configCard(notConfigured: boolean) {
    Column() {
      if (notConfigured) {
        Text($r('app.string.follow_updates_not_configured'))
          .fontSize(15)
          .fontColor(SysTheme.FONT_PRIMARY)
        Text($r('app.string.follow_updates_pick_folder'))
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ top: 8 })
      } else {
        Text(this.folder)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text($r('app.string.follow_updates_auto_hint'))
          .fontSize(13)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ top: 4 })
      }
      Row() {
        Button(notConfigured ? '选择收藏夹' : '更换收藏夹')
          .type(ButtonType.Capsule)
          .onClick(() => this.showFolderSelector())
        if (!notConfigured) {
          Button('立即检查')
            .type(ButtonType.Capsule)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .margin({ left: 8 })
            .enabled(!this.checking)
            .onClick(() => this.checkNow())
        }
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .margin({ left: 8, right: 8, top: 8 })
    .borderRadius(8)
    .border({ width: 0.6, color: '#33000000' })
    .alignItems(HorizontalAlign.Start)
  }
}
