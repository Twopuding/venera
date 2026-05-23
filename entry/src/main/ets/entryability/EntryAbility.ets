import { AbilityConstant, common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppBootstrapLite } from '../common/services/AppBootstrapLite';
import { AppDataService } from '../common/services/AppDataService';
import { ENGINE_READY_KEY, STARTUP_SPLASH_MESSAGE_KEY } from '../common/constants/StartupKeys';
import {
  SAFE_AREA_BOTTOM_VP_KEY,
  SAFE_AREA_TOP_VP_KEY
} from '../common/layout/SafeAreaInsets';

const DOMAIN = 0x0000;
const TAG = 'VeneraEntry';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    AppStorage.setOrCreate(ENGINE_READY_KEY, false);
    AppStorage.setOrCreate(STARTUP_SPLASH_MESSAGE_KEY, $r('app.string.startup_initializing'));
    windowStage.loadContent('pages/LaunchPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load LaunchPage: %{public}s', JSON.stringify(err));
        this.openMainPage(windowStage);
        return;
      }
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        mainWindow.setWindowLayoutFullScreen(true);
        EntryAbility.syncSafeAreaInsets(mainWindow);
        EntryAbility.applySystemBarStyle(this.context, mainWindow);
      });
      setTimeout(() => {
        this.openMainPage(windowStage);
      }, 50);
    });
  }

  private async openMainPage(windowStage: window.WindowStage): Promise<void> {
    try {
      await AppBootstrapLite.run(this.context);
      if (!AppDataService.getInstance().isFirstLaunchComplete()) {
        hilog.info(DOMAIN, TAG, 'First launch: running prep on LaunchPage');
        const mod = await import('../common/services/AppBootstrap');
        await mod.AppBootstrap.runFirstLaunchPrep(this.context);
        await AppDataService.getInstance().markFirstLaunchComplete();
      }
      windowStage.loadContent('pages/Index', (loadErr) => {
        if (loadErr.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load Index: %{public}s', JSON.stringify(loadErr));
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'openMainPage failed: %{public}s', `${e}`);
      windowStage.loadContent('pages/Index');
    }
  }

  private static syncSafeAreaInsets(mainWindow: window.Window): void {
    const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const topPx = systemArea.topRect.height;
    const bottomPx = navArea.bottomRect.height > 0 ? navArea.bottomRect.height : systemArea.bottomRect.height;
    const topVp = mainWindow.getUIContext().px2vp(topPx);
    const bottomVp = mainWindow.getUIContext().px2vp(bottomPx);
    AppStorage.setOrCreate(SAFE_AREA_TOP_VP_KEY, topVp);
    AppStorage.setOrCreate(SAFE_AREA_BOTTOM_VP_KEY, bottomVp);
  }

  private static applySystemBarStyle(context: common.UIAbilityContext, mainWindow: window.Window): void {
    const mode = context.config.colorMode;
    const isDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const contentColor = isDark ? '#FFFFFFFF' : '#FF000000';
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
