import { AppDataService } from '../services/AppDataService';
import { HistoryService } from '../services/HistoryService';
import { LocalFavoritesService } from '../services/LocalFavoritesService';

/** 漫画块角标状态 — 对齐 upstream ComicTile.build 收藏/历史判断 */
export interface ComicTileStatus {
  isFavorite: boolean;
  /** 1-based 阅读页码，0 表示不显示历史角标 */
  historyPage: number;
  historyMaxPage: number;
}

export async function loadComicTileStatus(comicId: string, sourceKey: string): Promise<ComicTileStatus> {
  const settings = AppDataService.getInstance().settings;
  const status: ComicTileStatus = { isFavorite: false, historyPage: 0, historyMaxPage: 0 };
  if (settings.showFavoriteStatusOnTile) {
    status.isFavorite = await LocalFavoritesService.getInstance().isExistAsync(comicId, sourceKey);
  }
  if (settings.showHistoryStatusOnTile) {
    const history = HistoryService.getInstance().find(comicId, sourceKey);
    if (history !== undefined) {
      let page = history.pageIndex + 1;
      if (page < 1) {
        page = 1;
      }
      status.historyPage = page;
      if (history.maxPage !== undefined && history.maxPage > 0) {
        status.historyMaxPage = history.maxPage;
      }
    }
  }
  return status;
}

export function comicTileStatusVisible(status: ComicTileStatus): boolean {
  return status.isFavorite || status.historyPage > 0;
}
