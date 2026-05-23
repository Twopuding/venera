import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceDataService } from '../../common/services/ComicSourceDataService';
import { WebCookieBridge } from '../../common/services/WebCookieBridge';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 漫画源 WebView 登录 — API 23 ArkWeb + Cookie 同步 */
@Entry
@Component
struct SourceLoginWebPage {
  @State loginUrl: string = 'https://example.com';
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State pageTitle: string = '源登录';
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? '';
    this.loginUrl = params['loginUrl'] ?? this.loginUrl;
    this.pageTitle = this.sourceName.length > 0 ? `${this.sourceName} 登录` : '漫画源登录';
    WebCookieBridge.applyToWeb(this.loginUrl);
  }

  private finishLogin(): void {
    WebCookieBridge.syncFromWeb(this.loginUrl);
    if (this.sourceKey.length > 0) {
      ComicSourceDataService.getInstance().saveData(this.sourceKey, 'account', 'ok');
    }
    try {
      promptAction.showToast({ message: '登录信息已保存', duration: 2000 });
    } catch (_e) {
      console.info('[SourceLoginWebPage] login saved');
    }
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.pageTitle,
        trailing: () => {
          Button('完成')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .onClick(() => this.finishLogin())
        }
      })

      Text(this.loginUrl)
        .fontSize(11)
        .fontColor(SysTheme.FONT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12, bottom: 8 })

      Web({ src: this.loginUrl, controller: this.webController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .layoutWeight(1)
        .width('100%')

      Button('清除 Cookie')
        .width('100%')
        .margin({ left: 12, right: 12, bottom: 12 })
        .onClick(() => {
          WebCookieBridge.clearWebCookies();
          this.webController.refresh();
        })
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
