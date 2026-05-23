import { common } from '@kit.AbilityKit';
import { LocalComicService } from './LocalComicService';
import { ComicSourceService } from './ComicSourceService';
import { JsEngineBridge } from './JsEngineBridge';
import { FavoritesService } from './FavoritesService';
import { DownloadService } from './DownloadService';
import { HistoryService } from './HistoryService';
import { MaterialEffectHelper } from '../material/MaterialEffectHelper';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';
import { JsUiBridge } from './JsUiBridge';
import { JsCookieStore } from './JsCookieStore';
import { TagTranslationService } from './TagTranslationService';
import { ENGINE_READY_KEY, STARTUP_SPLASH_MESSAGE_KEY } from '../constants/StartupKeys';

/** 主界面显示后的延迟初始化；首次安装时在 LaunchPage 上完成重型 prep */
export class AppBootstrap {
  private static deferredStarted: boolean = false;

  private static setMessage(message: ResourceStr): void {
    AppStorage.setOrCreate(STARTUP_SPLASH_MESSAGE_KEY, message);
  }

  private static yieldToUi(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 16);
    });
  }

  /**
   * 仅首次安装后执行：在仍显示 LaunchPage 时完成 QuickJS / 默认图源装入，
   * 避免 loadContent(Index) 首次 AOT 编译时长时间白屏。
   */
  static async runFirstLaunchPrep(context: common.UIAbilityContext): Promise<void> {
    if (AppBootstrap.deferredStarted) {
      return;
    }
    AppBootstrap.deferredStarted = true;
    AppStorage.setOrCreate(ENGINE_READY_KEY, false);
    AppBootstrap.setMessage($r('app.string.startup_first_install'));
    ImageCacheUtil.init(context);
    JsUiBridge.init(context);
    JsCookieStore.getInstance().init(context);
    await ComicSourceService.getInstance().init(context);
    await AppBootstrap.yieldToUi();
    await MaterialEffectHelper.initialize();
    await HistoryService.getInstance().init(context);
    await LocalComicService.getInstance().init(context);
    await FavoritesService.getInstance().init(context);
    await DownloadService.getInstance().init(context);
    TagTranslationService.init(context);
    AppBootstrap.setMessage($r('app.string.startup_loading_engine'));
    await AppBootstrap.yieldToUi();
    await ComicSourceService.getInstance().ensureEngineReady();
    AppBootstrap.setMessage($r('app.string.startup_loading_sources'));
    await AppBootstrap.yieldToUi();
    await ComicSourceService.getInstance().loadStagedScriptsFromDisk();
    await ComicSourceService.getInstance().installDefaultSourceScripts(false);
    await JsEngineBridge.getInstance().registerPendingStagedInBackground();
    await ComicSourceService.getInstance().syncFromNetwork();
    ComicSourceService.getInstance().markEngineFullyReady();
    console.info('[AppBootstrap] first-launch prep complete');
  }

  /** 非首次冷启动：主界面显示后后台补齐（首次已在 prep 中完成） */
  static startupDeferred(context: common.UIAbilityContext): void {
    if (AppBootstrap.deferredStarted) {
      return;
    }
    AppBootstrap.deferredStarted = true;
    AppStorage.setOrCreate(ENGINE_READY_KEY, false);
    setTimeout(async () => {
      try {
        ImageCacheUtil.init(context);
        JsUiBridge.init(context);
        JsCookieStore.getInstance().init(context);
        await ComicSourceService.getInstance().init(context);
        await MaterialEffectHelper.initialize();
        await HistoryService.getInstance().init(context);
        await LocalComicService.getInstance().init(context);
        await FavoritesService.getInstance().init(context);
        await DownloadService.getInstance().init(context);
        TagTranslationService.init(context);
        await ComicSourceService.getInstance().ensureEngineReady();
        await ComicSourceService.getInstance().loadStagedScriptsFromDisk();
        await ComicSourceService.getInstance().installDefaultSourceScripts(false);
        await JsEngineBridge.getInstance().registerPendingStagedInBackground();
        await ComicSourceService.getInstance().syncFromNetwork();
        ComicSourceService.getInstance().markEngineFullyReady();
        console.info('[AppBootstrap] deferred startup complete');
      } catch (e) {
        console.warn(`[AppBootstrap] deferred startup failed: ${e}`);
      }
    }, 100);
  }
}
