import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 应用级 RDB（本地收藏 / 图片收藏）— 对齐上游 SQLite local_favorite.db + history.db 中的 image_favorites
 */
export class VeneraRdbService {
  private static instance: VeneraRdbService;
  private store?: relationalStore.RdbStore;
  private initPromise?: Promise<void>;

  static getInstance(): VeneraRdbService {
    if (!VeneraRdbService.instance) {
      VeneraRdbService.instance = new VeneraRdbService();
    }
    return VeneraRdbService.instance;
  }

  async ensureReady(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store;
    }
    if (!this.initPromise) {
      this.initPromise = this.openStore(context);
    }
    await this.initPromise;
    if (!this.store) {
      throw new Error('RDB store not initialized');
    }
    return this.store;
  }

  private async openStore(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'venera_local.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS folder_order (
        folder_name TEXT PRIMARY KEY,
        order_value INTEGER
      );
    `);
    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS folder_sync (
        folder_name TEXT PRIMARY KEY,
        source_key TEXT,
        source_folder TEXT
      );
    `);
    await this.store.executeSql(`
      CREATE TABLE IF NOT EXISTS image_favorites (
        id TEXT,
        title TEXT NOT NULL,
        sub_title TEXT,
        author TEXT,
        tags TEXT,
        translated_tags TEXT,
        time INTEGER,
        max_page INTEGER,
        source_key TEXT NOT NULL,
        image_favorites_ep TEXT NOT NULL,
        other TEXT NOT NULL,
        PRIMARY KEY (id, source_key)
      );
    `);
  }

  getStore(): relationalStore.RdbStore | undefined {
    return this.store;
  }
}
