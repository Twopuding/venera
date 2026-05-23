import { Comic } from '../models/ComicModels';
import { AppDataService } from '../services/AppDataService';

/**
 * 关键词屏蔽 — 对齐 upstream lib/components/comic.dart isBlocked
 */
export class BlockedWordsUtil {
  static isComicBlocked(comic: Comic): boolean {
    const words = AppDataService.getInstance().settings.blockedWords;
    if (words.length === 0) {
      return false;
    }
    for (let i = 0; i < words.length; i++) {
      if (BlockedWordsUtil.comicMatchesWord(comic, words[i])) {
        return true;
      }
    }
    return false;
  }

  static isCommentBlocked(text: string): boolean {
    const words = AppDataService.getInstance().settings.blockedCommentWords;
    if (words.length === 0 || text.length === 0) {
      return false;
    }
    for (let i = 0; i < words.length; i++) {
      if (text.indexOf(words[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  static filterComics(comics: Comic[]): Comic[] {
    const words = AppDataService.getInstance().settings.blockedWords;
    if (words.length === 0) {
      return comics;
    }
    return comics.filter((c: Comic) => !BlockedWordsUtil.isComicBlocked(c));
  }

  private static comicMatchesWord(comic: Comic, word: string): boolean {
    if (word.length === 0) {
      return false;
    }
    if (comic.title.indexOf(word) >= 0) {
      return true;
    }
    if (comic.subtitle && comic.subtitle.indexOf(word) >= 0) {
      return true;
    }
    if (comic.description.indexOf(word) >= 0) {
      return true;
    }
    if (comic.tags) {
      for (let t = 0; t < comic.tags.length; t++) {
        const tag = comic.tags[t];
        if (tag === word) {
          return true;
        }
        const colon = tag.indexOf(':');
        if (colon >= 0) {
          const part = tag.substring(colon + 1);
          if (part === word) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
