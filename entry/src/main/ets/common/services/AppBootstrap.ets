import { common } from '@kit.AbilityKit';
import { AppDataService } from './AppDataService';
import { LocalComicService } from './LocalComicService';
import { ComicSourceService } from './ComicSourceService';
import { JsEngineBridge } from './JsEngineBridge';
import { FavoritesService } from './FavoritesService';
import { LocalFavoritesService } from './LocalFavoritesService';
import { ImageFavoriteService } from './ImageFavoriteService';
import { FollowUpdatesService } from './FollowUpdatesService';
import { DownloadService } from './DownloadService';
import { HistoryService } from './HistoryService';
import { MaterialEffectHelper } from '../material/MaterialEffectHelper';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';
import { ImageFavoriteImageUtil } from '../utils/ImageFavoriteImageUtil';
import { JsUiBridge } from './JsUiBridge';
import { JsCookieStore } from './JsCookieStore';
import { TagTranslationService } from './TagTranslationService';
import { ENGINE_READY_KEY, STARTUP_SPLASH_MESSAGE_KEY } from '../constants/StartupKeys';

/** 主界面显示后的延迟初始化（含首次安装的引擎与图源装入） */
export class AppBootstrap {
  private static deferredStarted: boolean = false;
  private static readonly ENGINE_INIT_TIMEOUT_MS: number = 120000;

  private static setMessage(message: ResourceStr): void {
    AppStorage.setOrCreate(STARTUP_SPLASH_MESSAGE_KEY, message);
  }

  private static yieldToUi(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 16);
    });
  }

  static startupDeferred(context: common.UIAbilityContext): void {
    if (AppBootstrap.deferredStarted) {
      return;
    }
    AppBootstrap.deferredStarted = true;
    AppStorage.setOrCreate(ENGINE_READY_KEY, false);
    const isFirstLaunch = !AppDataService.getInstance().isFirstLaunchComplete();
    if (isFirstLaunch) {
      AppBootstrap.setMessage($r('app.string.startup_first_install'));
    }
    setTimeout(async () => {
      try {
        ImageCacheUtil.init(context);
        ImageFavoriteImageUtil.init(context);
        JsUiBridge.init(context);
        JsCookieStore.getInstance().init(context);
        await ComicSourceService.getInstance().init(context);
        await MaterialEffectHelper.initialize();
        await HistoryService.getInstance().init(context);
        await LocalComicService.getInstance().init(context);
        await FavoritesService.getInstance().init(context);
        await LocalFavoritesService.getInstance().init(context);
        await ImageFavoriteService.getInstance().init(context);
        await DownloadService.getInstance().init(context);
        TagTranslationService.init(context);
        AppBootstrap.setMessage($r('app.string.startup_loading_init_js'));
        await AppBootstrap.yieldToUi();
        AppBootstrap.setMessage($r('app.string.startup_loading_engine'));
        await AppBootstrap.yieldToUi();
        const engineOk = await AppBootstrap.ensureEngineWithTimeout(context);
        if (!engineOk) {
          console.error('[AppBootstrap] engine init failed or timeout, continuing');
        }
        AppBootstrap.setMessage($r('app.string.startup_loading_sources'));
        await AppBootstrap.yieldToUi();
        await ComicSourceService.getInstance().loadStagedScriptsFromDisk();
        await ComicSourceService.getInstance().installDefaultSourceScripts(false);
        await JsEngineBridge.getInstance().registerPendingStagedInBackground();
        await ComicSourceService.getInstance().syncFromNetwork();
        ComicSourceService.getInstance().markEngineFullyReady();
        FollowUpdatesService.getInstance().initChecker();
        if (isFirstLaunch) {
          await AppDataService.getInstance().markFirstLaunchComplete();
        }
        console.info('[AppBootstrap] deferred startup complete');
      } catch (e) {
        console.warn(`[AppBootstrap] deferred startup failed: ${e}`);
      }
    }, 100);
  }

  private static async ensureEngineWithTimeout(_context: common.UIAbilityContext): Promise<boolean> {
    try {
      await Promise.race([
        ComicSourceService.getInstance().ensureEngineReady(),
        new Promise<void>((_resolve, reject) => {
          setTimeout(() => reject(new Error('engine init timeout')), AppBootstrap.ENGINE_INIT_TIMEOUT_MS);
        })
      ]);
      return JsEngineBridge.getInstance().getStatus().runtimeReady;
    } catch (e) {
      console.error(`[AppBootstrap] ensureEngineReady: ${e}`);
      return false;
    }
  }
}
