import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { AppDataService } from '../../common/services/AppDataService';
import { HttpService } from '../../common/services/HttpService';
import { AppConstants } from '../../common/constants/AppConstants';
import { ComicSourceInfo } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 官方漫画源列表 — 对齐上游 _ComicSourceList */
@Entry
@Component
struct ComicSourceListPage {
  @State repoUrl: string = '';
  @State loading: boolean = true;
  @State entries: ComicSourceInfo[] = [];
  @State installedKeys: string[] = [];
  @State urlChanged: boolean = false;

  aboutToAppear(): void {
    const settings = AppDataService.getInstance().settings;
    this.repoUrl = settings.comicSourceListUrl.length > 0 ?
      settings.comicSourceListUrl : AppConstants.CONFIG_INDEX_URL;
    this.refreshInstalled();
    this.loadIndex();
  }

  aboutToDisappear(): void {
    if (this.urlChanged) {
      AppDataService.getInstance().settings.comicSourceListUrl = this.repoUrl;
      AppDataService.getInstance().save();
    }
  }

  private refreshInstalled(): void {
    ComicSourceService.getInstance().getInstalledSources().then((list) => {
      const keys: string[] = [];
      for (let i = 0; i < list.length; i++) {
        keys.push(list[i].key);
      }
      this.installedKeys = keys;
    });
  }

  private async loadIndex(): Promise<void> {
    this.loading = true;
    let json = '';
    try {
      json = await HttpService.getInstance().get(this.repoUrl.trim());
    } catch (_e) {
      promptAction.showToast({ message: '网络错误', duration: 2000 });
      this.entries = [];
      this.loading = false;
      return;
    }
    this.entries = ComicSourceService.parseIndexFromJson(json);
    this.loading = false;
  }

  private async addEntry(entry: ComicSourceInfo): Promise<void> {
    const url = ComicSourceService.getInstance().resolveIndexScriptUrl(entry);
    const err = await ComicSourceService.getInstance().addSourceFromUrl(url);
    if (err.length > 0) {
      promptAction.showToast({ message: err, duration: 2500 });
      return;
    }
    this.refreshInstalled();
    promptAction.showToast({ message: '已添加', duration: 1500 });
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: $r('app.string.comic_source_list') })

      Column() {
        Text($r('app.string.repo_url'))
          .fontSize(13)
          .fontColor(SysTheme.FONT_PRIMARY)
          .width('100%')
        TextInput({ text: this.repoUrl, placeholder: 'index.json URL' })
          .margin({ top: 8 })
          .onChange((v: string) => {
            this.repoUrl = v;
            this.urlChanged = true;
          })
        Text($r('app.string.repo_url_hint'))
          .fontSize(11)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ top: 6 })
        Row() {
          Blank().layoutWeight(1)
          Button($r('app.string.refresh_sources'))
            .type(ButtonType.Capsule)
            .height(32)
            .onClick(() => this.loadIndex())
        }
        .margin({ top: 8 })
      }
      .padding(16)
      .margin({ left: 16, right: 16 })
      .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
      .borderRadius(12)

      if (this.loading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 24 })
      }

      List() {
        ForEach(this.entries, (entry: ComicSourceInfo) => {
          ListItem() {
            Row() {
              Column() {
                Text(entry.name)
                  .fontSize(15)
                  .fontColor(SysTheme.FONT_PRIMARY)
                Text(`${entry.version}\n${entry.description}`)
                  .fontSize(11)
                  .fontColor(SysTheme.FONT_SECONDARY)
                  .maxLines(3)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.installedKeys.indexOf(entry.key) >= 0) {
                Text('✓')
                  .fontSize(18)
                  .fontColor(SysTheme.EMPHASIZE)
              } else {
                Button($r('app.string.add'))
                  .type(ButtonType.Capsule)
                  .height(32)
                  .fontSize(12)
                  .onClick(() => this.addEntry(entry))
              }
            }
            .padding(12)
            .width('100%')
          }
        }, (entry: ComicSourceInfo) => entry.key)
      }
      .layoutWeight(1)
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
