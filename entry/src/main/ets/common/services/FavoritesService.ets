import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Comic } from '../models/ComicModels';

export interface FavoriteEntry {
  id: string;
  sourceKey: string;
  comicJson: string;
  addedAt: number;
}

/**
 * Favorites persistence — port of upstream foundation/favorites.dart.
 */
export class FavoritesService {
  private static instance: FavoritesService;
  private prefStore?: preferences.Preferences;
  private favorites: FavoriteEntry[] = [];

  static getInstance(): FavoritesService {
    if (!FavoritesService.instance) {
      FavoritesService.instance = new FavoritesService();
    }
    return FavoritesService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefStore = await preferences.getPreferences(context, 'venera_favorites');
    const raw = await this.prefStore.get('list', '[]') as string;
    try {
      this.favorites = JSON.parse(raw) as FavoriteEntry[];
    } catch (_e) {
      this.favorites = [];
    }
  }

  getAll(): FavoriteEntry[] {
    return this.favorites;
  }

  getComics(): Comic[] {
    return this.favorites.map((f: FavoriteEntry) => JSON.parse(f.comicJson) as Comic);
  }

  async add(comic: Comic): Promise<void> {
    const exists = this.favorites.some((f: FavoriteEntry) =>
      f.id === comic.id && f.sourceKey === comic.sourceKey);
    if (exists) {
      return;
    }
    const entry: FavoriteEntry = {
      id: comic.id,
      sourceKey: comic.sourceKey,
      comicJson: JSON.stringify(comic),
      addedAt: Date.now()
    };
    this.favorites.unshift(entry);
    await this.persist();
  }

  async remove(id: string, sourceKey: string): Promise<void> {
    this.favorites = this.favorites.filter((f: FavoriteEntry) =>
      !(f.id === id && f.sourceKey === sourceKey));
    await this.persist();
  }

  isFavorite(id: string, sourceKey: string): boolean {
    return this.favorites.some((f: FavoriteEntry) => f.id === id && f.sourceKey === sourceKey);
  }

  private async persist(): Promise<void> {
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put('list', JSON.stringify(this.favorites));
    await this.prefStore.flush();
  }
}
