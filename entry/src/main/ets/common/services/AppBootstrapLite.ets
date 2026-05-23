import { common } from '@kit.AbilityKit';
import { AppDataService } from './AppDataService';

/**
 * 极轻量启动：仅 Preferences。禁止 import ComicSourceService / JsEngineBridge（会加载 native .so）。
 */
export class AppBootstrapLite {
  private static done: boolean = false;

  static async run(context: common.UIAbilityContext): Promise<void> {
    if (AppBootstrapLite.done) {
      return;
    }
    await AppDataService.getInstance().init(context);
    AppBootstrapLite.done = true;
  }
}
