import { zlib } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

const ZIP_EXTENSIONS: string[] = ['.zip', '.cbz'];

/**
 * CBZ/ZIP 解压（API 23 @kit.BasicServicesKit zlib.decompressFile）。
 * 7z/cb7 需原生模块，当前仅提示不支持。
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
}
