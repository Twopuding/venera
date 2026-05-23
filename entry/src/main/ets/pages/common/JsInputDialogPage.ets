import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { INPUT_DIALOG_REQUEST_KEY, INPUT_DIALOG_RESULT_KEY } from '../../common/constants/UiDialogKeys';
import { SysTheme } from '../../common/theme/SysTheme';

/** 漫画源验证码 / UI.showInputDialog */
@Entry
@Component
struct JsInputDialogPage {
  @State title: string = '输入';
  @State inputText: string = '';
  private requestId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? '输入';
    this.requestId = params['requestId'] ?? '';
  }

  private submit(value: string | null): void {
    AppStorage.setOrCreate(INPUT_DIALOG_RESULT_KEY, JSON.stringify({
      requestId: this.requestId,
      value: value
    }));
    router.back();
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(SysTheme.FONT_PRIMARY)
        .padding(16)

      TextInput({ placeholder: '请输入…', text: this.inputText })
        .margin({ left: 16, right: 16 })
        .onChange((v: string) => { this.inputText = v; })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .onClick(() => this.submit(null))
        Button('确定')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .onClick(() => this.submit(this.inputText))
      }
      .padding(16)
      .margin({ top: 24 })
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
