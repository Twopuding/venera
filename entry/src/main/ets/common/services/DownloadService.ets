import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DownloadTask } from '../models/ComicModels';
import { HttpService } from './HttpService';
import { AppConstants } from '../constants/AppConstants';
import { ImageCacheUtil } from '../utils/ImageCacheUtil';

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

  async removeTask(taskId: string): Promise<void> {
    this.tasks = this.tasks.filter((t: DownloadTask) => t.id !== taskId);
    await this.persist();
    this.notify();
  }

  async retryTask(taskId: string): Promise<void> {
    const task = this.tasks.find((t: DownloadTask) => t.id === taskId);
    if (!task || task.status !== 'failed') {
      return;
    }
    task.status = 'pending';
    task.progress = 0;
    task.downloadedBytes = 0;
    task.totalBytes = 0;
    await this.persist();
    this.notify();
    this.processQueue();
  }

  async clearCompleted(): Promise<void> {
    this.tasks = this.tasks.filter((t: DownloadTask) => t.status !== 'completed');
    await this.persist();
    this.notify();
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
        const ext = ImageCacheUtil.extensionFromUrl(pending.resourceUrl);
        pending.destPath = `${this.downloadsPath}/${pending.id}${ext}`;
        this.notify();
        try {
          if (pending.resourceUrl.startsWith('file://')) {
            const src = pending.resourceUrl.substring(7);
            fileIo.copyFileSync(src, pending.destPath);
            const stat = fileIo.statSync(pending.destPath);
            pending.downloadedBytes = stat.size;
            pending.totalBytes = stat.size;
          } else {
            await HttpService.getInstance().downloadFile(pending.resourceUrl, pending.destPath,
              (received: number, total: number) => {
                pending.downloadedBytes = received;
                pending.totalBytes = total;
                pending.progress = total > 0 ? Math.min(99, Math.floor(received * 100 / total)) : 0;
                this.notify();
              });
          }
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
