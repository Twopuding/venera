import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { WebCookieBridge } from '../../common/services/WebCookieBridge';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 漫画源 WebView 登录 — 对齐上游 loginWithWebview + checkLoginStatus
 * API 23 ArkWeb + Cookie / localStorage 持久化
 */
@Entry
@Component
struct SourceLoginWebPage {
  @State loginUrl: string = 'https://example.com';
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State pageTitle: string = '源登录';
  @State currentUrl: string = '';
  @State finishing: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? '';
    this.loginUrl = params['loginUrl'] ?? this.loginUrl;
    this.currentUrl = this.loginUrl;
    this.pageTitle = this.sourceName.length > 0 ? `${this.sourceName} 登录` : '漫画源登录';
    WebCookieBridge.applyToWeb(this.loginUrl);
  }

  private async tryAutoFinishLogin(): Promise<void> {
    if (this.finishing || this.sourceKey.length === 0) {
      return;
    }
    const ok = await ComicSourceService.getInstance()
      .checkWebviewLoginStatus(this.sourceKey, this.currentUrl, this.pageTitle);
    if (!ok) {
      return;
    }
    this.finishing = true;
    const storageScript = 'JSON.stringify(Object.assign({}, window.localStorage))';
    try {
      this.webController.runJavaScript(storageScript, (err: Error, result: string) => {
        const json = err ? '' : (result ?? '');
        ComicSourceService.getInstance()
          .completeWebviewLogin(this.sourceKey, this.currentUrl, json)
          .then(() => {
            try {
              promptAction.showToast({ message: '登录成功', duration: 2000 });
            } catch (_e) {
              console.info('[SourceLoginWebPage] login ok');
            }
            router.back();
          })
          .catch((e: Error) => {
            this.finishing = false;
            promptAction.showToast({ message: `保存登录信息失败: ${e}`, duration: 2500 });
          });
      });
    } catch (_e) {
      ComicSourceService.getInstance()
        .completeWebviewLogin(this.sourceKey, this.currentUrl, '')
        .then(() => router.back())
        .catch(() => {
          this.finishing = false;
        });
    }
  }

  private manualFinish(): void {
    if (this.finishing) {
      return;
    }
    this.finishing = true;
    const storageScript = 'JSON.stringify(Object.assign({}, window.localStorage))';
    try {
      this.webController.runJavaScript(storageScript, (err: Error, result: string) => {
        const json = err ? '' : (result ?? '');
        ComicSourceService.getInstance()
          .completeWebviewLogin(this.sourceKey, this.currentUrl.length > 0 ? this.currentUrl : this.loginUrl, json)
          .then(() => {
            try {
              promptAction.showToast({ message: '登录信息已保存', duration: 2000 });
            } catch (_e) {
              console.info('[SourceLoginWebPage] login saved');
            }
            router.back();
          })
          .catch(() => {
            this.finishing = false;
          });
      });
    } catch (_e) {
      ComicSourceService.getInstance()
        .completeWebviewLogin(this.sourceKey, this.loginUrl, '')
        .then(() => router.back())
        .catch(() => {
          this.finishing = false;
        });
    }
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: this.pageTitle,
        trailing: () => {
          Button('完成')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .enabled(!this.finishing)
            .onClick(() => this.manualFinish())
        }
      })

      Text(this.currentUrl.length > 0 ? this.currentUrl : this.loginUrl)
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
        .onPageEnd(() => {
          this.tryAutoFinishLogin();
        })
        .onTitleReceive((event) => {
          if (event && event.title) {
            this.pageTitle = event.title;
          }
          this.tryAutoFinishLogin();
        })
        .onLoadIntercept((event) => {
          if (event && event.data) {
            const data = event.data;
            if (typeof data === 'string') {
              this.currentUrl = data;
            } else {
              try {
                this.currentUrl = data.getRequestUrl();
              } catch (_e) {
                // ignore
              }
            }
          }
          return false;
        })

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
