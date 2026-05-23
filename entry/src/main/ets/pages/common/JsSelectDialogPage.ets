import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { SELECT_DIALOG_REQUEST_KEY, SELECT_DIALOG_RESULT_KEY } from '../../common/constants/UiDialogKeys';
import { SysTheme } from '../../common/theme/SysTheme';

/** 漫画源 UI.showSelectDialog */
@Entry
@Component
struct JsSelectDialogPage {
  @State title: string = '选择';
  @State options: string[] = [];
  private requestId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.title = params['title'] ?? '选择';
    this.requestId = params['requestId'] ?? '';
    const optionsJson = params['optionsJson'] ?? '[]';
    try {
      this.options = JSON.parse(optionsJson) as string[];
    } catch (_e) {
      this.options = [];
    }
  }

  private finish(index: number | null): void {
    AppStorage.setOrCreate(SELECT_DIALOG_RESULT_KEY, JSON.stringify({
      requestId: this.requestId,
      index: index
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

      List() {
        ForEach(this.options, (opt: string, idx: number) => {
          ListItem() {
            Text(opt)
              .fontSize(15)
              .fontColor(SysTheme.FONT_PRIMARY)
              .padding(14)
              .width('100%')
              .onClick(() => this.finish(idx))
          }
        }, (opt: string) => opt)
      }
      .layoutWeight(1)

      Button('取消')
        .margin(16)
        .onClick(() => this.finish(null))
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
