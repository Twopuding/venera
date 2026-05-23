import { zlib } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { JsNativeRuntime } from '../services/JsNativeRuntime';

const ZIP_EXTENSIONS: string[] = ['.zip', '.cbz', '.epub'];

/**
 * 压缩包解压（API 23）。
 * ZIP/CBZ：zlib.decompressFile；7z/cb7：NAPI + LZMA SDK（scripts/fetch-lzma.ps1）。
 */
export class ArchiveExtractUtil {
  static isZipArchive(path: string): boolean {
    const lower = path.toLowerCase();
    return ZIP_EXTENSIONS.some((ext: string) => lower.endsWith(ext));
  }

  static is7zArchive(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.endsWith('.7z') || lower.endsWith('.cb7');
  }

  /**
   * 将 ZIP/CBZ 解压到已存在的沙箱目录（outDir 须预先 mkdir）。
   */
  static async extractZipToDir(archivePath: string, outDir: string): Promise<void> {
    if (!ArchiveExtractUtil.isZipArchive(archivePath)) {
      throw new Error(`Unsupported archive: ${archivePath}`);
    }
    try {
      fileIo.statSync(outDir);
    } catch (_e) {
      fileIo.mkdirSync(outDir, true);
    }
    await zlib.decompressFile(archivePath, outDir, {});
  }

  /**
   * 7z/cb7 解压到已存在目录（outDir 须预先 mkdir）。
   */
  static extract7zToDir(archivePath: string, outDir: string): void {
    if (!ArchiveExtractUtil.is7zArchive(archivePath)) {
      throw new Error(`Unsupported 7z archive: ${archivePath}`);
    }
    const ok = JsNativeRuntime.extract7z(archivePath, outDir);
    if (!ok) {
      throw new Error('7z extract failed (fetch-lzma.ps1 + rebuild required)');
    }
  }

  static async extractArchiveToDir(archivePath: string, outDir: string): Promise<void> {
    if (ArchiveExtractUtil.isZipArchive(archivePath)) {
      await ArchiveExtractUtil.extractZipToDir(archivePath, outDir);
      return;
    }
    if (ArchiveExtractUtil.is7zArchive(archivePath)) {
      ArchiveExtractUtil.extract7zToDir(archivePath, outDir);
      return;
    }
    throw new Error(`Unsupported archive: ${archivePath}`);
  }
}
