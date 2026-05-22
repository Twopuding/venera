import { common } from '@kit.AbilityKit';
import { AppDataService } from './AppDataService';
import { LocalComicService } from './LocalComicService';
import { ComicSourceService } from './ComicSourceService';
import { FavoritesService } from './FavoritesService';
import { DownloadService } from './DownloadService';
import { HistoryService } from './HistoryService';
import { MaterialEffectHelper } from '../material/MaterialEffectHelper';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';
import { JsCookieStore } from './JsCookieStore';

/** Application startup — mirrors upstream lib/init.dart */
export class AppBootstrap {
  private static booted: boolean = false;

  static async startup(context: common.UIAbilityContext): Promise<void> {
    if (AppBootstrap.booted) {
      return;
    }
    await MaterialEffectHelper.initialize();
    ImageCacheUtil.init(context);
    JsCookieStore.getInstance().init(context);
    await AppDataService.getInstance().init(context);
    await LocalComicService.getInstance().init(context);
    await FavoritesService.getInstance().init(context);
    await HistoryService.getInstance().init(context);
    await DownloadService.getInstance().init(context);
    await ComicSourceService.getInstance().init(context);
    AppBootstrap.booted = true;
  }
}
