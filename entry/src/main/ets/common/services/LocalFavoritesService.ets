import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Comic } from '../models/ComicModels';
import { FavoriteItem, FavoriteItemWithUpdateInfo } from '../models/FavoriteModels';
import { ComicTypeUtil } from '../utils/ComicTypeUtil';
import { TagTranslationService } from './TagTranslationService';
import { VeneraRdbService } from './VeneraRdbService';
import { AppDataService } from './AppDataService';
import { ComicSourceService } from './ComicSourceService';

/** 本地收藏夹（RDB 文件夹表）— 对齐 upstream LocalFavoritesManager */
export class LocalFavoritesService {
  static readonly LOCAL_ALL_FOLDER: string = '^_^[%local_all%]^_^';
  private static instance: LocalFavoritesService;
  private listeners: Array<() => void> = [];
  private folderCounts: Map<string, number> = new Map();
  private cachedFolderNames: string[] = [];

  static getInstance(): LocalFavoritesService {
    if (!LocalFavoritesService.instance) {
      LocalFavoritesService.instance = new LocalFavoritesService();
    }
    return LocalFavoritesService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    await VeneraRdbService.getInstance().ensureReady(context);
    await this.refreshFolderNames();
    await this.refreshFolderCounts();
    const followFolder = AppDataService.getInstance().settings.followUpdatesFolder;
    if (followFolder.length > 0 && this.existsFolder(followFolder)) {
      await this.prepareTableForFollowUpdates(followFolder, false);
    } else if (followFolder.length > 0) {
      AppDataService.getInstance().settings.followUpdatesFolder = '';
      await AppDataService.getInstance().save();
    }
    if (this.cachedFolderNames.length === 0) {
      await this.createFolder('默认');
    }
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }

  private formatTime(d: Date = new Date()): string {
    return d.toISOString().replace('T', ' ').substring(0, 19);
  }

  private escapeFolder(folder: string): string {
    if (folder.includes('"')) {
      throw new Error('Invalid folder name');
    }
    return `"${folder}"`;
  }

  private async execSql(sql: string, args: Array<relationalStore.ValueType> = []): Promise<void> {
    const store = VeneraRdbService.getInstance().getStore();
    if (!store) {
      return;
    }
    await store.executeSql(sql, args);
  }

  private async querySql(sql: string, args: Array<relationalStore.ValueType> = []): Promise<relationalStore.ResultSet> {
    const store = VeneraRdbService.getInstance().getStore();
    if (!store) {
      throw new Error('RDB not ready');
    }
    return store.querySql(sql, args);
  }

  async refreshFolderNames(): Promise<void> {
    const rs = await this.querySql(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT IN ('folder_order','folder_sync','image_favorites');",
      []
    );
    const names: string[] = [];
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      do {
        names.push(rs.getString(0));
      } while (rs.goToNextRow());
    }
    rs.close();
    const orderRs = await this.querySql('SELECT folder_name, order_value FROM folder_order;', []);
    const orderMap = new Map<string, number>();
    if (orderRs.rowCount > 0) {
      orderRs.goToFirstRow();
      do {
        orderMap.set(orderRs.getString(0), orderRs.getLong(1));
      } while (orderRs.goToNextRow());
    }
    orderRs.close();
    names.sort((a: string, b: string) => (orderMap.get(a) ?? 0) - (orderMap.get(b) ?? 0));
    this.cachedFolderNames = names;
  }

  folderNames(): string[] {
    return this.cachedFolderNames;
  }

  existsFolder(name: string): boolean {
    return this.cachedFolderNames.includes(name);
  }

  async createFolder(name: string): Promise<string> {
    let folder = name.trim();
    if (folder.length === 0) {
      let i = 0;
      while (this.existsFolder(`${i}`)) {
        i++;
      }
      folder = `${i}`;
    }
    if (this.existsFolder(folder)) {
      let i = 0;
      const base = folder;
      while (this.existsFolder(`${base}${i}`)) {
        i++;
      }
      folder = `${base}${i}`;
    }
    const tbl = this.escapeFolder(folder);
    await this.execSql(`
      CREATE TABLE IF NOT EXISTS ${tbl}(
        id TEXT,
        name TEXT,
        author TEXT,
        type INTEGER,
        tags TEXT,
        cover_path TEXT,
        time TEXT,
        display_order INTEGER,
        translated_tags TEXT,
        PRIMARY KEY (id, type)
      );
    `);
    this.folderCounts.set(folder, 0);
    await this.refreshFolderNames();
    this.notify();
    return folder;
  }

  async deleteFolder(name: string): Promise<void> {
    await this.execSql(`DROP TABLE IF EXISTS ${this.escapeFolder(name)};`);
    await this.execSql('DELETE FROM folder_order WHERE folder_name = ?;', [name]);
    await this.execSql('DELETE FROM folder_sync WHERE folder_name = ?;', [name]);
    this.folderCounts.delete(name);
    await this.refreshFolderNames();
    this.notify();
  }

  folderComicsCount(folder: string): number {
    return this.folderCounts.get(folder) ?? 0;
  }

  async count(folder: string): Promise<number> {
    if (!this.existsFolder(folder)) {
      return 0;
    }
    const rs = await this.querySql(`SELECT COUNT(*) AS c FROM ${this.escapeFolder(folder)};`, []);
    let c = 0;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      c = rs.getLong(0);
    }
    rs.close();
    this.folderCounts.set(folder, c);
    return c;
  }

  private async refreshFolderCounts(): Promise<void> {
    for (let i = 0; i < this.cachedFolderNames.length; i++) {
      await this.count(this.cachedFolderNames[i]);
    }
  }

  private parseRow(rs: relationalStore.ResultSet): FavoriteItem {
    const item = new FavoriteItem();
    item.id = rs.getString(rs.getColumnIndex('id'));
    item.name = rs.getString(rs.getColumnIndex('name'));
    item.author = rs.getString(rs.getColumnIndex('author'));
    item.type = rs.getLong(rs.getColumnIndex('type'));
    const tagsRaw = rs.getString(rs.getColumnIndex('tags'));
    item.tags = tagsRaw.length > 0 ? tagsRaw.split(',') : [];
    item.tags = item.tags.filter((t: string) => t.length > 0);
    item.coverPath = rs.getString(rs.getColumnIndex('cover_path'));
    item.time = rs.getString(rs.getColumnIndex('time'));
    item.sourceKey = ComicSourceService.getInstance().getSourceKeyByType(item.type);
    return item;
  }

  async getFolderComics(folder: string): Promise<FavoriteItem[]> {
    if (folder === LocalFavoritesService.LOCAL_ALL_FOLDER) {
      return this.getAllComics();
    }
    if (!this.existsFolder(folder)) {
      return [];
    }
    const rs = await this.querySql(
      `SELECT * FROM ${this.escapeFolder(folder)} ORDER BY display_order;`,
      []
    );
    const list: FavoriteItem[] = [];
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      do {
        list.push(this.parseRow(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return list;
  }

  async getAllComics(): Promise<FavoriteItem[]> {
    const folders = this.cachedFolderNames;
    const seen = new Set<string>();
    const list: FavoriteItem[] = [];
    for (let i = 0; i < folders.length; i++) {
      const comics = await this.getFolderComics(folders[i]);
      for (let j = 0; j < comics.length; j++) {
        const key = `${comics[j].type}::${comics[j].id}`;
        if (!seen.has(key)) {
          seen.add(key);
          list.push(comics[j]);
        }
      }
    }
    return list;
  }

  async comicExists(folder: string, id: string, type: number): Promise<boolean> {
    if (!this.existsFolder(folder)) {
      return false;
    }
    const rs = await this.querySql(
      `SELECT 1 FROM ${this.escapeFolder(folder)} WHERE id = ? AND type = ?;`,
      [id, type]
    );
    const ok = rs.rowCount > 0;
    rs.close();
    return ok;
  }

  async isExistAsync(id: string, sourceKey: string): Promise<boolean> {
    const type = ComicTypeUtil.typeFromSourceKey(sourceKey);
    const folders = await this.find(id, type);
    return folders.length > 0;
  }

  async find(id: string, type: number): Promise<string[]> {
    const res: string[] = [];
    for (let i = 0; i < this.cachedFolderNames.length; i++) {
      if (await this.comicExists(this.cachedFolderNames[i], id, type)) {
        res.push(this.cachedFolderNames[i]);
      }
    }
    return res;
  }

  private translateTags(tags: string[]): string {
    const res: string[] = [];
    for (let i = 0; i < tags.length; i++) {
      const translated = TagTranslationService.translateTagLine(tags[i]);
      if (translated !== tags[i]) {
        res.push(translated);
      }
    }
    return res.join(',');
  }

  private async maxDisplayOrder(folder: string): Promise<number> {
    const rs = await this.querySql(
      `SELECT MAX(display_order) AS m FROM ${this.escapeFolder(folder)};`,
      []
    );
    let m = 0;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      if (!rs.isColumnNull(rs.getColumnIndex('m'))) {
        m = rs.getLong(rs.getColumnIndex('m'));
      }
    }
    rs.close();
    return m;
  }

  async addComic(folder: string, item: FavoriteItem, updateTime?: string): Promise<boolean> {
    if (!this.existsFolder(folder)) {
      return false;
    }
    if (await this.comicExists(folder, item.id, item.type)) {
      return false;
    }
    const order = (await this.maxDisplayOrder(folder)) + 1;
    const translated = this.translateTags(item.tags);
    await this.execSql(
      `INSERT INTO ${this.escapeFolder(folder)}
       (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);`,
      [
        item.id,
        item.name,
        item.author,
        item.type,
        item.tags.join(','),
        item.coverPath,
        item.time.length > 0 ? item.time : this.formatTime(),
        translated,
        order
      ]
    );
    if (updateTime) {
      await this.updateUpdateTime(folder, item.id, item.type, updateTime);
    }
    await this.count(folder);
    this.notify();
    return true;
  }

  async addComicFromModel(folder: string, comic: Comic): Promise<boolean> {
    const item = new FavoriteItem();
    item.id = comic.id;
    item.name = comic.title;
    item.author = comic.subtitle ?? '';
    item.type = ComicTypeUtil.typeFromSourceKey(comic.sourceKey);
    item.tags = comic.tags ?? [];
    item.coverPath = comic.cover;
    item.time = this.formatTime();
    item.sourceKey = comic.sourceKey;
    return this.addComic(folder, item);
  }

  async deleteComicWithId(folder: string, id: string, type: number): Promise<void> {
    if (!this.existsFolder(folder)) {
      return;
    }
    await this.execSql(
      `DELETE FROM ${this.escapeFolder(folder)} WHERE id = ? AND type = ?;`,
      [id, type]
    );
    await this.count(folder);
    this.notify();
  }

  async removeFromAllFolders(id: string, sourceKey: string): Promise<void> {
    const type = ComicTypeUtil.typeFromSourceKey(sourceKey);
    const folders = await this.find(id, type);
    for (let i = 0; i < folders.length; i++) {
      await this.deleteComicWithId(folders[i], id, type);
    }
  }

  async prepareTableForFollowUpdates(table: string, clearData: boolean = true): Promise<void> {
    if (!this.existsFolder(table)) {
      return;
    }
    const tbl = this.escapeFolder(table);
    const infoRs = await this.querySql(`PRAGMA table_info(${tbl});`, []);
    const cols = new Set<string>();
    if (infoRs.rowCount > 0) {
      infoRs.goToFirstRow();
      do {
        cols.add(infoRs.getString(infoRs.getColumnIndex('name')));
      } while (infoRs.goToNextRow());
    }
    infoRs.close();
    if (!cols.has('last_update_time')) {
      await this.execSql(`ALTER TABLE ${tbl} ADD COLUMN last_update_time TEXT;`);
    }
    if (!cols.has('has_new_update')) {
      await this.execSql(`ALTER TABLE ${tbl} ADD COLUMN has_new_update INTEGER;`);
    }
    if (!cols.has('last_check_time')) {
      await this.execSql(`ALTER TABLE ${tbl} ADD COLUMN last_check_time INTEGER;`);
    }
    if (clearData) {
      await this.execSql(`UPDATE ${tbl} SET has_new_update = 0;`);
    }
  }

  async countUpdates(folder: string): Promise<number> {
    if (!this.existsFolder(folder)) {
      return 0;
    }
    const rs = await this.querySql(
      `SELECT COUNT(*) AS c FROM ${this.escapeFolder(folder)} WHERE has_new_update = 1;`,
      []
    );
    let c = 0;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      c = rs.getLong(0);
    }
    rs.close();
    return c;
  }

  async getComicsWithUpdatesInfo(folder: string): Promise<FavoriteItemWithUpdateInfo[]> {
    if (!this.existsFolder(folder)) {
      return [];
    }
    const rs = await this.querySql(`SELECT * FROM ${this.escapeFolder(folder)};`, []);
    const list: FavoriteItemWithUpdateInfo[] = [];
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      do {
        const base = this.parseRow(rs);
        const info = new FavoriteItemWithUpdateInfo();
        info.id = base.id;
        info.name = base.name;
        info.author = base.author;
        info.type = base.type;
        info.tags = base.tags;
        info.coverPath = base.coverPath;
        info.time = base.time;
        info.sourceKey = base.sourceKey;
        const utIdx = rs.getColumnIndex('last_update_time');
        if (utIdx >= 0 && !rs.isColumnNull(utIdx)) {
          info.updateTime = rs.getString(utIdx);
        }
        const hnIdx = rs.getColumnIndex('has_new_update');
        info.hasNewUpdate = hnIdx >= 0 && !rs.isColumnNull(hnIdx) && rs.getLong(hnIdx) === 1;
        const lcIdx = rs.getColumnIndex('last_check_time');
        if (lcIdx >= 0 && !rs.isColumnNull(lcIdx)) {
          info.lastCheckTime = rs.getLong(lcIdx);
        }
        list.push(info);
      } while (rs.goToNextRow());
    }
    rs.close();
    return list;
  }

  async updateInfo(folder: string, item: FavoriteItem): Promise<void> {
    await this.execSql(
      `UPDATE ${this.escapeFolder(folder)}
       SET name = ?, author = ?, cover_path = ?, tags = ?
       WHERE id = ? AND type = ?;`,
      [item.name, item.author, item.coverPath, item.tags.join(','), item.id, item.type]
    );
    this.notify();
  }

  async updateUpdateTime(folder: string, id: string, type: number, updateTime: string): Promise<void> {
    const rs = await this.querySql(
      `SELECT last_update_time FROM ${this.escapeFolder(folder)} WHERE id = ? AND type = ?;`,
      [id, type]
    );
    let oldTime = '';
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      if (!rs.isColumnNull(0)) {
        oldTime = rs.getString(0);
      }
    }
    rs.close();
    const hasNew = oldTime !== updateTime ? 1 : 0;
    await this.execSql(
      `UPDATE ${this.escapeFolder(folder)}
       SET last_update_time = ?, has_new_update = ?, last_check_time = ?
       WHERE id = ? AND type = ?;`,
      [updateTime, hasNew, Date.now(), id, type]
    );
    this.notify();
  }

  async updateCheckTime(folder: string, id: string, type: number): Promise<void> {
    await this.execSql(
      `UPDATE ${this.escapeFolder(folder)} SET last_check_time = ? WHERE id = ? AND type = ?;`,
      [Date.now(), id, type]
    );
  }

  async markAsRead(id: string, type: number): Promise<void> {
    const folder = AppDataService.getInstance().settings.followUpdatesFolder;
    if (folder.length === 0 || !this.existsFolder(folder)) {
      return;
    }
    await this.execSql(
      `UPDATE ${this.escapeFolder(folder)} SET has_new_update = 0 WHERE id = ? AND type = ?;`,
      [id, type]
    );
    this.notify();
  }

  async linkFolderToNetwork(folder: string, sourceKey: string, networkFolderId: string): Promise<void> {
    await this.execSql(
      'INSERT OR REPLACE INTO folder_sync (folder_name, source_key, source_folder) VALUES (?, ?, ?);',
      [folder, sourceKey, networkFolderId]
    );
  }

  async isLinkedToNetworkFolder(
    folder: string,
    sourceKey: string,
    networkFolderId: string
  ): Promise<boolean> {
    const rs = await this.querySql(
      'SELECT 1 FROM folder_sync WHERE folder_name = ? AND source_key = ? AND source_folder = ?;',
      [folder, sourceKey, networkFolderId]
    );
    const ok = rs.rowCount > 0;
    rs.close();
    return ok;
  }

  async findLinked(folder: string): Promise<[string | null, string | null]> {
    const rs = await this.querySql(
      'SELECT source_key, source_folder FROM folder_sync WHERE folder_name = ?;',
      [folder]
    );
    if (rs.rowCount === 0) {
      rs.close();
      return [null, null];
    }
    rs.goToFirstRow();
    const sourceKey = rs.getString(0);
    const networkFolder = rs.getString(1);
    rs.close();
    return [sourceKey, networkFolder];
  }

  private async minDisplayOrder(folder: string): Promise<number> {
    const rs = await this.querySql(
      `SELECT MIN(display_order) AS m FROM ${this.escapeFolder(folder)};`,
      []
    );
    let m = 0;
    if (rs.rowCount > 0) {
      rs.goToFirstRow();
      if (!rs.isColumnNull(rs.getColumnIndex('m'))) {
        m = rs.getLong(rs.getColumnIndex('m'));
      }
    }
    rs.close();
    return m;
  }

  async batchDeleteComics(folder: string, comics: FavoriteItem[]): Promise<void> {
    if (!this.existsFolder(folder) || comics.length === 0) {
      return;
    }
    const tbl = this.escapeFolder(folder);
    for (let i = 0; i < comics.length; i++) {
      await this.execSql(
        `DELETE FROM ${tbl} WHERE id = ? AND type = ?;`,
        [comics[i].id, comics[i].type]
      );
    }
    await this.count(folder);
    this.notify();
  }

  async batchCopyFavorites(
    sourceFolder: string,
    targetFolder: string,
    comics: FavoriteItem[]
  ): Promise<void> {
    if (!this.existsFolder(sourceFolder) || !this.existsFolder(targetFolder) || comics.length === 0) {
      return;
    }
    const src = this.escapeFolder(sourceFolder);
    const dst = this.escapeFolder(targetFolder);
    let order = (await this.maxDisplayOrder(targetFolder)) + 1;
    for (let i = 0; i < comics.length; i++) {
      const c = comics[i];
      if (await this.comicExists(targetFolder, c.id, c.type)) {
        continue;
      }
      await this.execSql(
        `INSERT OR IGNORE INTO ${dst}
         (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
         SELECT id, name, author, type, tags, cover_path, time, translated_tags, ?
         FROM ${src} WHERE id = ? AND type = ?;`,
        [order, c.id, c.type]
      );
      order++;
    }
    await this.count(targetFolder);
    this.notify();
  }

  async batchMoveFavorites(
    sourceFolder: string,
    targetFolder: string,
    comics: FavoriteItem[]
  ): Promise<void> {
    if (!this.existsFolder(sourceFolder) || !this.existsFolder(targetFolder) || comics.length === 0) {
      return;
    }
    const src = this.escapeFolder(sourceFolder);
    const dst = this.escapeFolder(targetFolder);
    let order = (await this.maxDisplayOrder(targetFolder)) + 1;
    for (let i = 0; i < comics.length; i++) {
      const c = comics[i];
      if (!(await this.comicExists(sourceFolder, c.id, c.type))) {
        continue;
      }
      if (!(await this.comicExists(targetFolder, c.id, c.type))) {
        await this.execSql(
          `INSERT INTO ${dst}
           (id, name, author, type, tags, cover_path, time, translated_tags, display_order)
           SELECT id, name, author, type, tags, cover_path, time, translated_tags, ?
           FROM ${src} WHERE id = ? AND type = ?;`,
          [order, c.id, c.type]
        );
        order++;
      }
      await this.execSql(
        `DELETE FROM ${src} WHERE id = ? AND type = ?;`,
        [c.id, c.type]
      );
    }
    await this.count(sourceFolder);
    await this.count(targetFolder);
    this.notify();
  }
}
