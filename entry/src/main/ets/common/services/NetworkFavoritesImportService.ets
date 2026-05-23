import { promptAction } from '@kit.ArkUI';
import { Comic } from '../models/ComicModels';
import { FavoriteItem } from '../models/FavoriteModels';
import { ComicTypeUtil } from '../utils/ComicTypeUtil';
import { ComicSourceService } from './ComicSourceService';
import { LocalFavoritesService } from './LocalFavoritesService';

/**
 * 网络收藏转本地 — 对齐 upstream lib/pages/favorites/favorite_actions.dart importNetworkFolder
 */
export class NetworkFavoritesImportService {
  private static instance: NetworkFavoritesImportService;

  static getInstance(): NetworkFavoritesImportService {
    if (!NetworkFavoritesImportService.instance) {
      NetworkFavoritesImportService.instance = new NetworkFavoritesImportService();
    }
    return NetworkFavoritesImportService.instance;
  }

  async importNetworkFolder(
    sourceKey: string,
    updatePageNum: number,
    localFolderName: string | null,
    networkFolderId: string | null
  ): Promise<void> {
    const sourceTitle = ComicSourceService.getInstance().getNetworkFavoriteTitle(sourceKey);
    let resultName = localFolderName ?? sourceTitle;
    if (resultName.trim().length === 0) {
      resultName = sourceKey;
    }
    const folderId = networkFolderId ?? '';
    const exists = LocalFavoritesService.getInstance().existsFolder(resultName);
    if (exists) {
      const linked = await LocalFavoritesService.getInstance()
        .isLinkedToNetworkFolder(resultName, sourceKey, folderId);
      if (!linked) {
        promptAction.showToast({ message: '同名收藏夹已存在且未关联此网络收藏' });
        return;
      }
    } else {
      await LocalFavoritesService.getInstance().createFolder(resultName);
      await LocalFavoritesService.getInstance().linkFolderToNetwork(resultName, sourceKey, folderId);
    }

    let imported = 0;
    let requestCount = 0;
    let received = 0;
    let finished = false;
    let canceled = false;
    let errorMsg = '';
    let nextToken = '';
    let page = 1;
    const pending: FavoriteItem[] = [];

    const fetchNext = async (): Promise<void> => {
      let result = await ComicSourceService.getInstance()
        .loadNetworkFavoriteComics(sourceKey, page, folderId.length > 0 ? folderId : null);
      if (nextToken.length > 0) {
        result = await ComicSourceService.getInstance()
          .loadNetworkFavoriteNext(sourceKey, nextToken, folderId.length > 0 ? folderId : null);
      }
      if (result.error.length > 0) {
        throw new Error(result.error);
      }
      received += result.comics.length;
      for (let i = 0; i < result.comics.length; i++) {
        const c = result.comics[i];
        const type = ComicTypeUtil.typeFromSourceKey(c.sourceKey);
        if (!(await LocalFavoritesService.getInstance().comicExists(resultName, c.id, type))) {
          const item = NetworkFavoritesImportService.comicToFavorite(c);
          pending.push(item);
          imported++;
        }
      }
      requestCount++;
      if (result.next.length > 0) {
        nextToken = result.next;
      } else if (result.comics.length === 0 || page >= result.maxPage) {
        finished = true;
      } else {
        page++;
        nextToken = '';
      }
    };

    try {
      while (!finished && !canceled && requestCount < updatePageNum) {
        await fetchNext();
      }
    } catch (e) {
      errorMsg = `${e}`;
    }

    for (let i = 0; i < pending.length; i++) {
      await LocalFavoritesService.getInstance().addComic(resultName, pending[i]);
    }

    if (errorMsg.length > 0) {
      promptAction.showToast({
        message: `导入 ${imported} 部，已请求 ${requestCount} 页；错误：${errorMsg}`
      });
    } else {
      promptAction.showToast({
        message: `已导入 ${imported} 部漫画（加载 ${requestCount} 页，共收到 ${received} 条）`
      });
    }
  }

  private static comicToFavorite(c: Comic): FavoriteItem {
    const item = new FavoriteItem();
    item.id = c.id;
    item.name = c.title;
    item.author = c.subtitle ?? '';
    item.type = ComicTypeUtil.typeFromSourceKey(c.sourceKey);
    item.tags = c.tags ?? [];
    item.coverPath = c.cover;
    item.sourceKey = c.sourceKey;
    return item;
  }
}
