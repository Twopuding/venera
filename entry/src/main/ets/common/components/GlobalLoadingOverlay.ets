import { LOADING_ID_KEY, LOADING_VISIBLE_KEY } from '../constants/UiDialogKeys';

/** init.js UI.showLoading 全屏遮罩（API 23） */
@Component
export struct GlobalLoadingOverlay {
  @StorageLink(LOADING_VISIBLE_KEY) loadingVisible: boolean = false;
  @StorageLink(LOADING_ID_KEY) loadingId: number = 0;

  build() {
    if (this.loadingVisible) {
      Stack() {
        Column() {
          LoadingProgress().width(48).height(48)
          Text('加载中…')
            .fontSize(14)
            .fontColor('#FFFFFFFF')
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#99000000')
      .hitTestBehavior(HitTestMode.Block)
    }
  }
}
