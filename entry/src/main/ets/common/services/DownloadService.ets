import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DownloadTask } from '../models/ComicModels';
import { HttpService } from './HttpService';
import { AppConstants } from '../constants/AppConstants';

/**
 * Download queue — port of upstream network/download.dart.
 */
export class DownloadService {
  private static instance: DownloadService;
  private tasks: DownloadTask[] = [];
  private prefStore?: preferences.Preferences;
  private listeners: Array<() => void> = [];
  private downloadsPath: string = '';
  private processing: boolean = false;

  static getInstance(): DownloadService {
    if (!DownloadService.instance) {
      DownloadService.instance = new DownloadService();
    }
    return DownloadService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.downloadsPath = `${context.filesDir}/${AppConstants.DOWNLOADS_DIR}`;
    try {
      fileIo.mkdirSync(this.downloadsPath, true);
    } catch (_e) {
      // exists
    }
    this.prefStore = await preferences.getPreferences(context, 'venera_downloads');
    const raw = await this.prefStore.get('tasks', '[]') as string;
    try {
      this.tasks = JSON.parse(raw) as DownloadTask[];
    } catch (_e) {
      this.tasks = [];
    }
  }

  getDownloadsPath(): string {
    return this.downloadsPath;
  }

  getTasks(): DownloadTask[] {
    return this.tasks;
  }

  onChange(listener: () => void): void {
    this.listeners.push(listener);
  }

  private notify(): void {
    this.listeners.forEach((l: () => void) => l());
  }

  async enqueue(task: DownloadTask): Promise<void> {
    this.tasks.unshift(task);
    await this.persist();
    this.notify();
    this.processQueue();
  }

  private async processQueue(): Promise<void> {
    if (this.processing) {
      return;
    }
    this.processing = true;
    try {
      while (true) {
        const pending = this.tasks.find((t: DownloadTask) => t.status === 'pending');
        if (!pending) {
          break;
        }
        if (pending.resourceUrl.length === 0) {
          pending.status = 'failed';
          await this.persist();
          this.notify();
          continue;
        }
        pending.status = 'downloading';
        pending.destPath = `${this.downloadsPath}/${pending.id}.dat`;
        this.notify();
        try {
          await HttpService.getInstance().downloadFile(pending.resourceUrl, pending.destPath,
            (received: number, total: number) => {
              pending.downloadedBytes = received;
              pending.totalBytes = total;
              pending.progress = total > 0 ? Math.min(99, Math.floor(received * 100 / total)) : 0;
              this.notify();
            });
          pending.progress = 100;
          pending.status = 'completed';
        } catch (_e) {
          pending.status = 'failed';
        }
        await this.persist();
        this.notify();
      }
    } finally {
      this.processing = false;
    }
  }

  private async persist(): Promise<void> {
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put('tasks', JSON.stringify(this.tasks));
    await this.prefStore.flush();
  }
}
