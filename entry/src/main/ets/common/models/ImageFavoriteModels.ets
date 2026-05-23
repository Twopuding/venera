/** 图片收藏模型 — 对齐 upstream lib/foundation/image_favorites.dart */

export const IMAGE_FAVORITE_FIRST_PAGE: number = 1;

export class ImageFavorite {
  page: number = 0;
  imageKey: string = '';
  isAutoFavorite?: boolean;
  eid: string = '';
  id: string = '';
  ep: number = 0;
  sourceKey: string = '';
  epName: string = '';

  constructor(
    page: number,
    imageKey: string,
    isAutoFavorite: boolean | undefined,
    eid: string,
    id: string,
    ep: number,
    sourceKey: string,
    epName: string
  ) {
    this.page = page;
    this.imageKey = imageKey;
    this.isAutoFavorite = isAutoFavorite;
    this.eid = eid;
    this.id = id;
    this.ep = ep;
    this.sourceKey = sourceKey;
    this.epName = epName;
  }

  copyWith(page?: number, imageKey?: string, isAutoFavorite?: boolean): ImageFavorite {
    return new ImageFavorite(
      page ?? this.page,
      imageKey ?? this.imageKey,
      isAutoFavorite ?? this.isAutoFavorite,
      this.eid,
      this.id,
      this.ep,
      this.sourceKey,
      this.epName
    );
  }

  equals(other: ImageFavorite): boolean {
    return this.id === other.id &&
      this.sourceKey === other.sourceKey &&
      this.page === other.page &&
      this.eid === other.eid &&
      this.ep === other.ep;
  }
}

export class ImageFavoritesEp {
  eid: string = '';
  ep: number = 0;
  maxPage: number = 1;
  epName: string = '';
  imageFavorites: ImageFavorite[] = [];

  constructor(
    eid: string,
    ep: number,
    imageFavorites: ImageFavorite[],
    epName: string,
    maxPage: number
  ) {
    this.eid = eid;
    this.ep = ep;
    this.imageFavorites = imageFavorites;
    this.epName = epName;
    this.maxPage = maxPage;
  }
}

export class ImageFavoritesComic {
  id: string = '';
  title: string = '';
  subTitle: string = '';
  author: string = '';
  sourceKey: string = '';
  maxPage: number = 0;
  tags: string[] = [];
  translatedTags: string[] = [];
  time: number = 0;
  imageFavoritesEp: ImageFavoritesEp[] = [];
  other: Record<string, Object> = {};

  constructor(
    id: string,
    imageFavoritesEp: ImageFavoritesEp[],
    title: string,
    sourceKey: string,
    tags: string[],
    translatedTags: string[],
    time: number,
    author: string,
    other: Record<string, Object>,
    subTitle: string,
    maxPage: number
  ) {
    this.id = id;
    this.imageFavoritesEp = imageFavoritesEp;
    this.title = title;
    this.sourceKey = sourceKey;
    this.tags = tags;
    this.translatedTags = translatedTags;
    this.time = time;
    this.author = author;
    this.other = other;
    this.subTitle = subTitle;
    this.maxPage = maxPage;
  }

  get imageCount(): number {
    let count = 0;
    for (let i = 0; i < this.imageFavoritesEp.length; i++) {
      count += this.imageFavoritesEp[i].imageFavorites.length;
    }
    return count;
  }

  /** 各话 maxPage 之和 — 对齐 upstream maxPageFromEp */
  get maxPageFromEp(): number {
    let total = 0;
    for (let i = 0; i < this.imageFavoritesEp.length; i++) {
      total += this.imageFavoritesEp[i].maxPage;
    }
    return total;
  }

  /** 扁平化全部收藏页 — 对齐 upstream images */
  get images(): ImageFavorite[] {
    const list: ImageFavorite[] = [];
    for (let i = 0; i < this.imageFavoritesEp.length; i++) {
      const ep = this.imageFavoritesEp[i];
      for (let j = 0; j < ep.imageFavorites.length; j++) {
        list.push(ep.imageFavorites[j]);
      }
    }
    return list;
  }
}
