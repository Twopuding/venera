/** 本地收藏模型 — 对齐 upstream foundation/favorites.dart */

export class FavoriteItem {
  id: string = '';
  name: string = '';
  author: string = '';
  type: number = 0;
  tags: string[] = [];
  coverPath: string = '';
  time: string = '';
  sourceKey: string = '';

  get title(): string {
    return this.name;
  }

  get subtitle(): string {
    return this.author;
  }

  get cover(): string {
    return this.coverPath;
  }
}

export class FavoriteItemWithUpdateInfo extends FavoriteItem {
  updateTime?: string;
  hasNewUpdate: boolean = false;
  lastCheckTime?: number;
}
