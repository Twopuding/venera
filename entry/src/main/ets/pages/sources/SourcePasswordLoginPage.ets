import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { SourceAccountConfig } from '../../common/models/ComicModels';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/**
 * 漫画源账号登录 — 对齐上游 _LoginPage（密码 / Cookie 字段 / WebView 入口）
 */
@Entry
@Component
struct SourcePasswordLoginPage {
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State username: string = '';
  @State password: string = '';
  @State loading: boolean = false;
  @State pageReady: boolean = false;
  @State accountCfg: SourceAccountConfig | null = null;
  @State cookieValues: string[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? '';
    this.initPage();
  }

  private async initPage(): Promise<void> {
    if (!JsEngineBridge.getInstance().getStatus().runtimeReady) {
      promptAction.showToast({ message: '漫画源引擎未就绪', duration: 2500 });
      return;
    }
    const ready = await ComicSourceService.getInstance().ensureSourceReady(this.sourceKey);
    if (!ready) {
      promptAction.showToast({ message: '漫画源尚未装入，请返回重试', duration: 2500 });
      return;
    }
    this.accountCfg = await ComicSourceService.getInstance().getSourceAccount(this.sourceKey);
    if (this.accountCfg && this.accountCfg.cookieFields.length > 0) {
      this.cookieValues = [];
      for (let i = 0; i < this.accountCfg.cookieFields.length; i++) {
        this.cookieValues.push('');
      }
    }
    this.pageReady = true;
  }

  private openRegisterSite(): void {
    const url = this.accountCfg?.registerWebsite ?? '';
    if (url.length === 0) {
      return;
    }
    const ctx = ComicSourceService.getInstance().getContext();
    if (!ctx) {
      return;
    }
    ctx.openLink(url, { appLinkingOnly: false }).catch((e: Error) => {
      console.error(`[SourcePasswordLoginPage] open register: ${e}`);
    });
  }

  private async submitPassword(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0) {
      promptAction.showToast({ message: '用户名和密码不能为空', duration: 2000 });
      return;
    }
    this.loading = true;
    const err = await ComicSourceService.getInstance()
      .loginWithPassword(this.sourceKey, this.username, this.password);
    this.loading = false;
    if (err.length > 0) {
      promptAction.showToast({ message: err, duration: 3000 });
      return;
    }
    promptAction.showToast({ message: '登录成功', duration: 1500 });
    router.back();
  }

  private async submitCookies(): Promise<void> {
    if (!this.accountCfg) {
      return;
    }
    for (let i = 0; i < this.accountCfg.cookieFields.length; i++) {
      if ((this.cookieValues[i] ?? '').length === 0) {
        promptAction.showToast({ message: '请填写全部 Cookie 字段', duration: 2000 });
        return;
      }
    }
    this.loading = true;
    const err = await ComicSourceService.getInstance()
      .loginWithCookies(this.sourceKey, [...this.cookieValues]);
    this.loading = false;
    if (err.length > 0) {
      promptAction.showToast({ message: err, duration: 3000 });
      return;
    }
    promptAction.showToast({ message: '登录成功', duration: 1500 });
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: `${this.sourceName} · 登录` })

      if (!this.pageReady) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 48 })
      } else if (this.accountCfg && this.accountCfg.cookieFields.length > 0) {
        ForEach(this.accountCfg.cookieFields, (field: string, index: number) => {
          TextInput({ placeholder: field, text: this.cookieValues[index] ?? '' })
            .type(InputType.Password)
            .margin({ left: 24, right: 24, top: index === 0 ? 16 : 8, bottom: 8 })
            .onChange((v: string) => {
              this.cookieValues[index] = v;
            })
        }, (field: string) => field)

        Button('继续')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .width('80%')
          .margin({ top: 8 })
          .enabled(!this.loading)
          .onClick(() => this.submitCookies())

        if (this.loading) {
          LoadingProgress().width(28).height(28).margin({ top: 16 })
        }
      } else {
        if (this.accountCfg && !this.accountCfg.hasPasswordLogin && !this.accountCfg.hasCookieLogin) {
          Row() {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
              .fontSize(18)
              .fontColor([SysTheme.FONT_SECONDARY])
            Text('该图源未启用密码登录')
              .fontSize(14)
              .fontColor(SysTheme.FONT_SECONDARY)
              .margin({ left: 8 })
          }
          .margin({ top: 24, left: 24, right: 24 })
        } else if (this.accountCfg?.hasPasswordLogin) {
          TextInput({ placeholder: '用户名 / 邮箱', text: this.username })
            .margin({ left: 24, right: 24, top: 16, bottom: 12 })
            .onChange((v: string) => {
              this.username = v;
            })

          TextInput({ placeholder: '密码', text: this.password })
            .type(InputType.Password)
            .margin({ left: 24, right: 24, bottom: 24 })
            .onChange((v: string) => {
              this.password = v;
            })
            .onSubmit(() => this.submitPassword())

          Button('继续')
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .width('80%')
            .enabled(!this.loading)
            .onClick(() => this.submitPassword())
        }

        if (this.accountCfg && this.accountCfg.loginWebsite.length > 0) {
          Button($r('app.string.webview_login'))
            .type(ButtonType.Capsule)
            .margin({ top: 16 })
            .onClick(() => {
              ComicSourceService.getInstance()
                .openSourceLoginWeb(this.sourceKey, this.sourceName, this.accountCfg?.loginWebsite);
            })
        }

        if (this.accountCfg && this.accountCfg.registerWebsite.length > 0) {
          Button('注册账号')
            .type(ButtonType.Normal)
            .margin({ top: 12 })
            .onClick(() => this.openRegisterSite())
        }

        if (this.loading) {
          LoadingProgress().width(28).height(28).margin({ top: 16 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
