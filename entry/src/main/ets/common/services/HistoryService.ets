import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ReadingHistoryEntry } from '../models/ComicModels';

/**
 * 阅读历史 — 对应 upstream foundation/history.dart（Preferences 简化版）。
 */
export class HistoryService {
  private static instance: HistoryService;
  private prefStore?: preferences.Preferences;
  private entries: ReadingHistoryEntry[] = [];
  private listeners: Array<() => void> = [];

  static getInstance(): HistoryService {
    if (!HistoryService.instance) {
      HistoryService.instance = new HistoryService();
    }
    return HistoryService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefStore = await preferences.getPreferences(context, 'venera_history');
    const raw = await this.prefStore.get('entries', '[]') as string;
    try {
      this.entries = JSON.parse(raw) as ReadingHistoryEntry[];
    } catch (_e) {
      this.entries = [];
    }
  }

  getEntries(): ReadingHistoryEntry[] {
    return this.entries;
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  find(comicId: string, sourceKey: string): ReadingHistoryEntry | undefined {
    return this.entries.find((e: ReadingHistoryEntry) =>
      e.comicId === comicId && e.sourceKey === sourceKey);
  }

  async record(entry: ReadingHistoryEntry): Promise<void> {
    const idx = this.entries.findIndex((e: ReadingHistoryEntry) =>
      e.comicId === entry.comicId && e.sourceKey === entry.sourceKey);
    entry.updatedAt = Date.now();
    if (idx >= 0) {
      this.entries.splice(idx, 1);
    }
    this.entries.unshift(entry);
    if (this.entries.length > 200) {
      this.entries.pop();
    }
    await this.persist();
    this.listeners.forEach((l: () => void) => l());
  }

  /** WebDAV 拉取后合并历史（按 comicId+sourceKey，保留较新 updatedAt） */
  async mergeFromRemote(remote: ReadingHistoryEntry[]): Promise<void> {
    const map = new Map<string, ReadingHistoryEntry>();
    for (let i = 0; i < this.entries.length; i++) {
      const e = this.entries[i];
      map.set(`${e.sourceKey}::${e.comicId}`, e);
    }
    for (let i = 0; i < remote.length; i++) {
      const r = remote[i];
      const key = `${r.sourceKey}::${r.comicId}`;
      const existing = map.get(key);
      if (!existing || r.updatedAt > existing.updatedAt) {
        map.set(key, r);
      }
    }
    this.entries = Array.from(map.values());
    this.entries.sort((a: ReadingHistoryEntry, b: ReadingHistoryEntry) => b.updatedAt - a.updatedAt);
    if (this.entries.length > 200) {
      this.entries = this.entries.slice(0, 200);
    }
    await this.persist();
    this.listeners.forEach((l: () => void) => l());
  }

  private async persist(): Promise<void> {
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put('entries', JSON.stringify(this.entries));
    await this.prefStore.flush();
  }
}
