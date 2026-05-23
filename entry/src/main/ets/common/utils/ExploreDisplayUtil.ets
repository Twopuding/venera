import { AppDataService } from '../services/AppDataService';

/** 探索/列表漫画块显示参数 — 对齐 upstream SliverGridDelegateWithComics */
export class ExploreDisplayUtil {
  static isBriefMode(): boolean {
    return AppDataService.getInstance().settings.comicDisplayMode === 'brief';
  }

  static tileScale(): number {
    const s = AppDataService.getInstance().settings.comicTileScale;
    if (s < 0.5) {
      return 0.5;
    }
    if (s > 1.5) {
      return 1.5;
    }
    return s;
  }

  static gridColumnsTemplate(): string {
    return ExploreDisplayUtil.isBriefMode() ? '1fr 1fr 1fr 1fr' : '1fr 1fr 1fr';
  }
}
