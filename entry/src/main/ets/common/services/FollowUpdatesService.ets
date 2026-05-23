import { FavoriteItem, FavoriteItemWithUpdateInfo } from '../models/FavoriteModels';
import { Comic } from '../models/ComicModels';
import { LocalFavoritesService } from './LocalFavoritesService';
import { AppDataService } from './AppDataService';
import { JsEngineBridge } from './JsEngineBridge';
import { ComicSourceService } from './ComicSourceService';
import { ComicUpdateUtil } from '../utils/ComicUpdateUtil';

export class UpdateProgress {
  total: number = 0;
  current: number = 0;
  errors: number = 0;
  updated: number = 0;
}

class ComicUpdateOutcome {
  updated: boolean = false;
  error: boolean = false;
}

/** 关注更新检测 — 对齐 upstream foundation/follow_updates.dart */
export class FollowUpdatesService {
  private static instance: FollowUpdatesService;
  private static cancelFlag: boolean = false;
  private static checking: boolean = false;
  private static checkerStarted: boolean = false;
  private listeners: Array<() => void> = [];

  static getInstance(): FollowUpdatesService {
    if (!FollowUpdatesService.instance) {
      FollowUpdatesService.instance = new FollowUpdatesService();
    }
    return FollowUpdatesService.instance;
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  notifyUi(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  cancelChecking(): void {
    FollowUpdatesService.cancelFlag = true;
  }

  initChecker(): void {
    if (FollowUpdatesService.checkerStarted) {
      return;
    }
    FollowUpdatesService.checkerStarted = true;
    setTimeout(() => {
      this.checkInBackground();
    }, 3000);
    setInterval(() => {
      this.checkInBackground();
    }, 10 * 60 * 1000);
  }

  private async checkInBackground(): Promise<void> {
    const folder = AppDataService.getInstance().settings.followUpdatesFolder;
    if (folder.length === 0 || FollowUpdatesService.checking) {
      return;
    }
    FollowUpdatesService.checking = true;
    FollowUpdatesService.cancelFlag = false;
    try {
      await this.updateFolder(folder, false, undefined);
    } finally {
      FollowUpdatesService.checking = false;
      this.notifyUi();
    }
  }

  async updateFolder(
    folder: string,
    ignoreCheckTime: boolean,
    onProgress?: (p: UpdateProgress) => void
  ): Promise<UpdateProgress> {
    const progress = new UpdateProgress();
    const mgr = LocalFavoritesService.getInstance();
    let comics = await mgr.getComicsWithUpdatesInfo(folder);
    const toUpdate: FavoriteItemWithUpdateInfo[] = [];
    for (let i = 0; i < comics.length; i++) {
      const c = comics[i];
      if (!ignoreCheckTime && c.lastCheckTime) {
        const days = (Date.now() - c.lastCheckTime) / (24 * 3600 * 1000);
        if (days < 1) {
          continue;
        }
      }
      toUpdate.push(c);
    }
    progress.total = toUpdate.length;
    onProgress?.(progress);

    for (let i = 0; i < toUpdate.length; i++) {
      if (FollowUpdatesService.cancelFlag) {
        break;
      }
      const comic = toUpdate[i];
      const sourceKey = comic.sourceKey.length > 0 ? comic.sourceKey :
        ComicSourceService.getInstance().getSourceKeyByType(comic.type);
      if (sourceKey.length === 0 || sourceKey === 'local') {
        progress.current++;
        onProgress?.(progress);
        continue;
      }
      const result = await FollowUpdatesService.updateOneComic(comic, folder, sourceKey);
      progress.current++;
      if (result.updated) {
        progress.updated++;
      }
      if (result.error) {
        progress.errors++;
      }
      onProgress?.(progress);
      if ((i + 1) % 5 === 0) {
        await FollowUpdatesService.delay(1000);
      }
    }
    return progress;
  }

  private static async updateOneComic(
    c: FavoriteItemWithUpdateInfo,
    folder: string,
    sourceKey: string
  ): Promise<ComicUpdateOutcome> {
    let retries = 3;
    while (retries > 0) {
      try {
        const info = await JsEngineBridge.getInstance().invokeComicInfo(sourceKey, c.id);
        const newInfo = info.comic;
        const newTags: string[] = [];
        if (newInfo.tags) {
          for (let t = 0; t < newInfo.tags.length; t++) {
            newTags.push(newInfo.tags[t]);
          }
        }
        const item = new FavoriteItem();
        item.id = c.id;
        item.name = newInfo.title.length > 0 ? newInfo.title : c.name;
        item.coverPath = newInfo.cover.length > 0 ? newInfo.cover : c.coverPath;
        item.author = newInfo.subtitle ?? c.author;
        item.type = c.type;
        item.tags = newTags;
        await LocalFavoritesService.getInstance().updateInfo(folder, item);

        const updateTime = ComicUpdateUtil.findUpdateTime(newInfo);
        if (updateTime && updateTime !== c.updateTime) {
          await LocalFavoritesService.getInstance().updateUpdateTime(folder, c.id, c.type, updateTime);
          const out = new ComicUpdateOutcome();
          out.updated = true;
          return out;
        }
        await LocalFavoritesService.getInstance().updateCheckTime(folder, c.id, c.type);
        const done = new ComicUpdateOutcome();
        return done;
      } catch (e) {
        retries--;
        if (retries === 0) {
          console.warn(`[FollowUpdates] ${c.id}: ${e}`);
          const err = new ComicUpdateOutcome();
          err.error = true;
          return err;
        }
        await FollowUpdatesService.delay(2000);
      }
    }
    const fail = new ComicUpdateOutcome();
    fail.error = true;
    return fail;
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
  }
}
