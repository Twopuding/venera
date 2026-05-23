import { common } from '@kit.AbilityKit';
import { MainShell } from './main/MainShell';
import { GlobalLoadingOverlay } from '../common/components/GlobalLoadingOverlay';
import { SysTheme } from '../common/theme/SysTheme';
import { LOADING_VISIBLE_KEY, LOADING_ID_KEY } from '../common/constants/UiDialogKeys';
import { AppBootstrap } from '../common/services/AppBootstrap';

@Entry
@Component
struct Index {
  private deferredBoot: boolean = false;

  aboutToAppear(): void {
    AppStorage.setOrCreate(LOADING_VISIBLE_KEY, false);
    AppStorage.setOrCreate(LOADING_ID_KEY, 0);
    if (!this.deferredBoot) {
      this.deferredBoot = true;
      const ctx = getContext(this) as common.UIAbilityContext;
      AppBootstrap.startupDeferred(ctx);
    }
  }

  build() {
    Stack() {
      Column() {
        MainShell()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(SysTheme.BACKGROUND_PRIMARY)

      GlobalLoadingOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
