import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { AppConstants } from '../../common/constants/AppConstants';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';
import { ImageCacheUtil } from '../../common/utils/ImageCacheUtil';
import { JsCookieStore } from '../../common/services/JsCookieStore';
import { WebCookieBridge } from '../../common/services/WebCookieBridge';
import { promptAction } from '@kit.ArkUI';
import { WebDavSyncService, WebDavSyncResult } from '../../common/services/WebDavSyncService';

@Entry
@Component
struct SettingsPage {
  @State readerMode: string = AppDataService.getInstance().settings.readerMode;
  @State enableTranslation: boolean = AppDataService.getInstance().settings.enableTranslation;
  @State proxy: string = AppDataService.getInstance().settings.proxy;
  @State webdavUrl: string = AppDataService.getInstance().settings.webdavUrl;
  @State webdavUsername: string = AppDataService.getInstance().settings.webdavUsername;
  @State webdavPassword: string = AppDataService.getInstance().settings.webdavPassword;
  @State syncHint: string = '';
  @State syncing: boolean = false;
  @State jsStatus: string = '';

  aboutToAppear(): void {
    const s = JsEngineBridge.getInstance().getStatus();
    this.jsStatus = `init.js ${s.initScriptLength} 字符 · 已暂存 ${s.stagedSourceCount} 源 · ${s.runtimeNote}`;
    const cfg = AppDataService.getInstance().settings;
    this.webdavUrl = cfg.webdavUrl;
    this.webdavUsername = cfg.webdavUsername;
    this.webdavPassword = cfg.webdavPassword;
  }

  private saveWebDav(): void {
    AppDataService.getInstance().settings.webdavUrl = this.webdavUrl;
    AppDataService.getInstance().settings.webdavUsername = this.webdavUsername;
    AppDataService.getInstance().settings.webdavPassword = this.webdavPassword;
    AppDataService.getInstance().save();
  }

  private async runSync(action: 'test' | 'upload' | 'download'): Promise<void> {
    this.saveWebDav();
    this.syncing = true;
    this.syncHint = '';
    let result: WebDavSyncResult;
    if (action === 'test') {
      result = await WebDavSyncService.testConnection();
    } else if (action === 'upload') {
      result = await WebDavSyncService.upload();
    } else {
      result = await WebDavSyncService.download();
    }
    this.syncHint = result.message;
    this.syncing = false;
    try {
      promptAction.showToast({ message: result.message, duration: 2500 });
    } catch (_e) {
      console.info(`[Settings] sync: ${result.message}`);
    }
  }

  build() {
    Column() {
        SecondaryPageHeader({ title: $r('app.string.settings') })

      List() {
        ListItem() {
          Row() {
            Text('阅读模式')
            Blank()
            Text(this.readerMode)
          }
          .width('100%')
          .padding(16)
          .onClick(() => {
            this.readerMode = this.readerMode === 'vertical' ? 'horizontal' : 'vertical';
            AppDataService.getInstance().settings.readerMode = this.readerMode;
            AppDataService.getInstance().save();
          })
        }
        ListItem() {
          Column() {
            Text('网络代理')
              .fontSize(15)
            TextInput({ placeholder: 'http://127.0.0.1:7890', text: this.proxy })
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.proxy = v;
                AppDataService.getInstance().settings.proxy = v;
                AppDataService.getInstance().save();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        ListItem() {
          Row() {
            Text($r('app.string.search_sources_settings'))
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([SysTheme.FONT_SECONDARY])
          }
          .width('100%')
          .padding(16)
          .onClick(() => router.pushUrl({ url: 'pages/settings/SearchSourcesSettingsPage' }))
        }
        ListItem() {
          Row() {
            Text($r('app.string.explore_pages_settings'))
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([SysTheme.FONT_SECONDARY])
          }
          .width('100%')
          .padding(16)
          .onClick(() => router.pushUrl({ url: 'pages/explore/ExplorePagesPickerPage' }))
        }
        ListItem() {
          Row() {
            Text('标签翻译')
            Toggle({ type: ToggleType.Switch, isOn: this.enableTranslation })
              .onChange((on: boolean) => {
                this.enableTranslation = on;
                AppDataService.getInstance().settings.enableTranslation = on;
                AppDataService.getInstance().save();
              })
          }
          .width('100%')
          .padding(16)
        }
        ListItem() {
          Column() {
            Text($r('app.string.webdav_sync'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
            Text($r('app.string.webdav_hint'))
              .fontSize(11)
              .fontColor(SysTheme.FONT_SECONDARY)
              .margin({ top: 4, bottom: 8 })
            TextInput({ placeholder: 'https://dav.example.com/remote/venera/', text: this.webdavUrl })
              .onChange((v: string) => {
                this.webdavUrl = v;
                this.saveWebDav();
              })
            TextInput({ placeholder: '用户名', text: this.webdavUsername })
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.webdavUsername = v;
                this.saveWebDav();
              })
            TextInput({ placeholder: '密码', text: this.webdavPassword })
              .type(InputType.Password)
              .margin({ top: 8 })
              .onChange((v: string) => {
                this.webdavPassword = v;
                this.saveWebDav();
              })
            Row({ space: 8 }) {
              Button($r('app.string.webdav_test'))
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .layoutWeight(1)
                .enabled(!this.syncing)
                .onClick(() => this.runSync('test'))
              Button($r('app.string.webdav_upload'))
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .layoutWeight(1)
                .enabled(!this.syncing)
                .onClick(() => this.runSync('upload'))
              Button($r('app.string.webdav_download'))
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .layoutWeight(1)
                .enabled(!this.syncing)
                .onClick(() => this.runSync('download'))
            }
            .margin({ top: 12 })
            if (this.syncHint.length > 0) {
              Text(this.syncHint)
                .fontSize(11)
                .fontColor(SysTheme.FONT_SECONDARY)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        ListItem() {
          Text(`上游版本 ${AppConstants.UPSTREAM_VERSION}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
        ListItem() {
          Text(`鸿蒙版本 ${AppConstants.HARMONY_VERSION}`)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
        ListItem() {
          Text(this.jsStatus)
            .fontSize(13)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding(16)
        }
        ListItem() {
          Button('清空阅读器图片缓存')
            .width('100%')
            .onClick(() => {
              ImageCacheUtil.clearDiskCache();
              try {
                promptAction.showToast({ message: '图片缓存已清空', duration: 2000 });
              } catch (_e) {
                console.info('[Settings] image cache cleared');
              }
            })
        }
        .padding({ left: 16, right: 16, bottom: 8 })
        ListItem() {
          Button($r('app.string.clear_login_data'))
            .width('100%')
            .onClick(() => {
              JsCookieStore.getInstance().clearAll();
              WebCookieBridge.clearWebCookies();
              try {
                promptAction.showToast({ message: '登录 Cookie 已清除', duration: 2000 });
              } catch (_e) {
                console.info('[Settings] cookies cleared');
              }
            })
        }
        .padding({ left: 16, right: 16, bottom: 8 })
        ListItem() {
          Button($r('app.string.downloads'))
            .width('100%')
            .onClick(() => router.pushUrl({ url: 'pages/download/DownloadPage' }))
        }
        .padding({ left: 16, right: 16, bottom: 8 })
      }
      .layoutWeight(1)

      Text($r('app.string.about_title'))
        .fontSize(16)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding({ left: 16, top: 8 })
      Text($r('app.string.port_from'))
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .padding(16)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
