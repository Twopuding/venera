import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { VeneraRdbService } from './VeneraRdbService';
import {
  IMAGE_FAVORITE_FIRST_PAGE,
  ImageFavorite,
  ImageFavoritesComic,
  ImageFavoritesEp
} from '../models/ImageFavoriteModels';

export { ImageFavoritesComic } from '../models/ImageFavoriteModels';

/**
 * 图片收藏 — 对齐 upstream ImageFavoriteManager
 */
export class ImageFavoriteService {
  private static instance: ImageFavoriteService;
  private listeners: Array<() => void> = [];
  private cachedLength: number = 0;

  static getInstance(): ImageFavoriteService {
    if (!ImageFavoriteService.instance) {
      ImageFavoriteService.instance = new ImageFavoriteService();
    }
    return ImageFavoriteService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    await VeneraRdbService.getInstance().ensureReady(context);
    this.cachedLength = await this.loadLength();
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  private async querySql(sql: string, args: Array<relationalStore.ValueType> = []): Promise<relationalStore.ResultSet> {
    const store = VeneraRdbService.getInstance().getStore();
    if (!store) {
      throw new Error('RDB not ready');
    }
    return store.querySql(sql, args);
  }

  private async execSql(sql: string, args: Array<relationalStore.ValueType> = []): Promise<void> {
    const store = VeneraRdbService.getInstance().getStore();
    if (store) {
      await store.executeSql(sql, args);
    }
  }

  getLength(): number {
    return this.cachedLength;
  }

  private async loadLength(): Promise<number> {
    const rs = await this.querySql('SELECT COUNT(*) FROM image_favorites;', []);
    let n = 0;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      n = rs.getLong(0);
    }
    rs.close();
    this.cachedLength = n;
    return n;
  }

  async refreshLength(): Promise<void> {
    await this.loadLength();
  }

  async getAll(keyword?: string): Promise<ImageFavoritesComic[]> {
    let rs: relationalStore.ResultSet;
    if (keyword && keyword.trim().length > 0) {
      const kw = `%${keyword.trim()}%`;
      rs = await this.querySql(
        `SELECT * FROM image_favorites
         WHERE title LIKE ? OR sub_title LIKE ? OR tags LIKE ? OR author LIKE ?;`,
        [kw, kw, kw, kw]
      );
    } else {
      rs = await this.querySql('SELECT * FROM image_favorites;', []);
    }
    const list: ImageFavoritesComic[] = [];
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      do {
        list.push(this.parseComicRow(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return list;
  }

  async search(keyword: string): Promise<ImageFavoritesComic[]> {
    if (keyword.trim().length === 0) {
      return [];
    }
    return this.getAll(keyword);
  }

  async find(id: string, sourceKey: string): Promise<ImageFavoritesComic | null> {
    const rs = await this.querySql(
      'SELECT * FROM image_favorites WHERE id = ? AND source_key = ?;',
      [id, sourceKey]
    );
    let comic: ImageFavoritesComic | null = null;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      comic = this.parseComicRow(rs);
    }
    rs.close();
    return comic;
  }

  async hasAsync(id: string, sourceKey: string, eid: string, page: number, ep: number): Promise<boolean> {
    const comic = await this.find(id, sourceKey);
    if (!comic) {
      return false;
    }
    for (let i = 0; i < comic.imageFavoritesEp.length; i++) {
      const epItem = comic.imageFavoritesEp[i];
      if (epItem.eid !== eid) {
        continue;
      }
      for (let j = 0; j < epItem.imageFavorites.length; j++) {
        const img = epItem.imageFavorites[j];
        if (img.page === page && img.ep === ep) {
          return true;
        }
      }
    }
    return false;
  }

  async addOrUpdateOrDelete(favorite: ImageFavoritesComic, notify: boolean = true): Promise<void> {
    if (favorite.imageFavoritesEp.length === 0) {
      await this.execSql(
        'DELETE FROM image_favorites WHERE id = ? AND source_key = ?;',
        [favorite.id, favorite.sourceKey]
      );
    } else {
      const tempEps: ImageFavoritesEp[] = [];
      for (let i = 0; i < favorite.imageFavoritesEp.length; i++) {
        const e = favorite.imageFavoritesEp[i];
        let found = false;
        for (let j = 0; j < tempEps.length; j++) {
          if (tempEps[j].ep === e.ep) {
            found = true;
            break;
          }
        }
        if (!found && e.ep > 0) {
          tempEps.push(e);
        }
      }
      tempEps.sort((a: ImageFavoritesEp, b: ImageFavoritesEp) => a.ep - b.ep);
      if (tempEps.length === 0) {
        throw new Error('Error: No ImageFavoritesEp');
      }
      const finalEpJson: Array<Record<string, Object>> = [];
      for (let ei = 0; ei < tempEps.length; ei++) {
        const e = tempEps[ei];
        const pageMap: Array<Record<string, Object>> = [];
        for (let j = 0; j < e.imageFavorites.length; j++) {
          const img = e.imageFavorites[j];
          if (img.page <= 0) {
            continue;
          }
          let dup = false;
          for (let k = 0; k < pageMap.length; k++) {
            if (pageMap[k]['page'] === img.page) {
              dup = true;
              break;
            }
          }
          if (!dup) {
            const row: Record<string, Object> = {
              'page': img.page,
              'imageKey': img.imageKey
            };
            if (img.isAutoFavorite !== undefined && img.isAutoFavorite !== null) {
              row['isAutoFavorite'] = img.isAutoFavorite;
            }
            pageMap.push(row);
          }
        }
        pageMap.sort((a: Record<string, Object>, b: Record<string, Object>) =>
          (a['page'] as number) - (b['page'] as number));
        const epObj: Record<string, Object> = {
          'eid': e.eid,
          'ep': e.ep,
          'maxPage': e.maxPage,
          'epName': e.epName,
          'imageFavorites': pageMap
        };
        finalEpJson.push(epObj);
      }
      await this.execSql(
        `INSERT OR REPLACE INTO image_favorites
         (id, title, sub_title, author, tags, translated_tags, time, max_page, source_key, image_favorites_ep, other)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
        [
          favorite.id,
          favorite.title,
          favorite.subTitle,
          favorite.author,
          favorite.tags.join(','),
          favorite.translatedTags.join(','),
          favorite.time,
          favorite.maxPage,
          favorite.sourceKey,
          JSON.stringify(finalEpJson),
          JSON.stringify(favorite.other)
        ]
      );
    }
    await this.refreshLength();
    if (notify) {
      this.notify();
    }
  }

  async deleteImageFavorite(imageFavoriteList: ImageFavorite[]): Promise<void> {
    if (imageFavoriteList.length === 0) {
      return;
    }
    const comicMap = new Map<string, ImageFavoritesComic>();
    for (let i = 0; i < imageFavoriteList.length; i++) {
      const item = imageFavoriteList[i];
      const mapKey = `${item.sourceKey}\0${item.id}`;
      let comic: ImageFavoritesComic | undefined = comicMap.get(mapKey);
      if (comic === undefined) {
        const found = await this.find(item.id, item.sourceKey);
        if (found === null) {
          continue;
        }
        comic = found;
        comicMap.set(mapKey, comic);
      }
      for (let ei = 0; ei < comic.imageFavoritesEp.length; ei++) {
        const epItem = comic.imageFavoritesEp[ei];
        if (epItem.ep !== item.ep) {
          continue;
        }
        const nextImages: ImageFavorite[] = [];
        for (let j = 0; j < epItem.imageFavorites.length; j++) {
          if (!epItem.imageFavorites[j].equals(item)) {
            nextImages.push(epItem.imageFavorites[j]);
          }
        }
        epItem.imageFavorites = nextImages;
        if (epItem.imageFavorites.length === 0) {
          comic.imageFavoritesEp.splice(ei, 1);
          ei--;
        }
      }
    }
    const comics = Array.from(comicMap.values());
    for (let i = 0; i < comics.length; i++) {
      await this.addOrUpdateOrDelete(comics[i], false);
    }
    this.notify();
  }

  private parseComicRow(rs: relationalStore.ResultSet): ImageFavoritesComic {
    const id = rs.getString(rs.getColumnIndex('id'));
    const title = rs.getString(rs.getColumnIndex('title'));
    const subTitle = rs.getString(rs.getColumnIndex('sub_title'));
    const author = rs.getString(rs.getColumnIndex('author'));
    const sourceKey = rs.getString(rs.getColumnIndex('source_key'));
    const tagsRaw = rs.getString(rs.getColumnIndex('tags'));
    const translatedRaw = rs.getString(rs.getColumnIndex('translated_tags'));
    const time = rs.getLong(rs.getColumnIndex('time'));
    const maxPage = rs.getLong(rs.getColumnIndex('max_page'));
    const epJson = rs.getString(rs.getColumnIndex('image_favorites_ep'));
    const otherRaw = rs.getString(rs.getColumnIndex('other'));
    const tags = tagsRaw.length > 0 ? tagsRaw.split(',') : [];
    const translatedTags = translatedRaw.length > 0 ? translatedRaw.split(',') : [];
    let other: Record<string, Object> = {};
    try {
      other = JSON.parse(otherRaw) as Record<string, Object>;
    } catch (_e) {
      other = {};
    }
    const eps: ImageFavoritesEp[] = [];
    try {
      const parsed = JSON.parse(epJson) as Array<Record<string, Object>>;
      for (let i = 0; i < parsed.length; i++) {
        const row = parsed[i];
        const epNum = typeof row['ep'] === 'number' ? row['ep'] as number : 0;
        const eid = `${row['eid'] ?? ''}`;
        const epName = `${row['epName'] ?? ''}`;
        const epMax = typeof row['maxPage'] === 'number' ? row['maxPage'] as number : 1;
        const imgsRaw = row['imageFavorites'];
        const imgs: ImageFavorite[] = [];
        if (Array.isArray(imgsRaw)) {
          const arr = imgsRaw as Array<Record<string, Object>>;
          for (let j = 0; j < arr.length; j++) {
            const imgRow = arr[j];
            imgs.push(new ImageFavorite(
              imgRow['page'] as number,
              `${imgRow['imageKey'] ?? ''}`,
              imgRow['isAutoFavorite'] as boolean | undefined,
              eid,
              id,
              epNum,
              sourceKey,
              epName
            ));
          }
        }
        eps.push(new ImageFavoritesEp(eid, epNum, imgs, epName, epMax));
      }
    } catch (_e) {
      // keep empty eps
    }
    return new ImageFavoritesComic(
      id, eps, title, sourceKey, tags, translatedTags, time, author, other, subTitle, maxPage
    );
  }

  async deleteComic(id: string, sourceKey: string): Promise<void> {
    await this.execSql(
      'DELETE FROM image_favorites WHERE id = ? AND source_key = ?;',
      [id, sourceKey]
    );
    await this.refreshLength();
    this.notify();
  }
}
