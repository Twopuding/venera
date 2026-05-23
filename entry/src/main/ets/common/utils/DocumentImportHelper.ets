import { fileIo, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

/**
 * 系统文档选择器封装（API 23 @kit.CoreFileKit picker）。
 * 文件夹选择依赖 FolderSelection 能力；手机端可回退为压缩包多选。
 */
export class DocumentImportHelper {
  static async pickComicFolder(context: common.UIAbilityContext): Promise<string | null> {
    const docPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.maxSelectNumber = 1;
    try {
      const uris = await docPicker.select(options);
      if (uris && uris.length > 0) {
        return uris[0];
      }
    } catch (e) {
      console.warn(`[DocumentImportHelper] folder pick failed: ${e}`);
    }
    return null;
  }

  static async pickArchiveFiles(context: common.UIAbilityContext): Promise<string[]> {
    const docPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['.cbz', '.zip', '.7z', '.cb7', '.epub'];
    options.maxSelectNumber = 32;
    try {
      const uris = await docPicker.select(options);
      return uris ?? [];
    } catch (e) {
      console.warn(`[DocumentImportHelper] archive pick failed: ${e}`);
      return [];
    }
  }

  /** 从 document URI 提取可用作目录名的片段 */
  static folderNameFromUri(uri: string): string {
    const decoded = decodeURIComponent(uri);
    const parts = decoded.split('/').filter((p: string) => p.length > 0);
    let name = parts.length > 0 ? parts[parts.length - 1] : `comic_${Date.now()}`;
    if (name.includes('?')) {
      name = name.split('?')[0];
    }
    return name.replace(/[\\/:*?"<>|]/g, '_');
  }

  static async pickPdfFiles(context: common.UIAbilityContext): Promise<string[]> {
    const docPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['.pdf'];
    options.maxSelectNumber = 8;
    try {
      const uris = await docPicker.select(options);
      return uris ?? [];
    } catch (e) {
      console.warn(`[DocumentImportHelper] pdf pick failed: ${e}`);
      return [];
    }
  }

  static archiveNameFromUri(uri: string): string {
    const base = DocumentImportHelper.folderNameFromUri(uri);
    const dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  /** 选择 .js 漫画源配置文件 */
  static async pickJsFile(context: common.UIAbilityContext): Promise<string | null> {
    const docPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['.js'];
    options.maxSelectNumber = 1;
    try {
      const uris = await docPicker.select(options);
      if (uris && uris.length > 0) {
        return uris[0];
      }
    } catch (e) {
      console.warn(`[DocumentImportHelper] js pick failed: ${e}`);
    }
    return null;
  }

  static readTextFromUri(uri: string): string {
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(uri);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      const bytes = new Uint8Array(buf);
      let text = '';
      for (let i = 0; i < bytes.length; i++) {
        text += String.fromCharCode(bytes[i]);
      }
      return text;
    } catch (e) {
      console.error(`[DocumentImportHelper] readTextFromUri: ${e}`);
      return '';
    }
  }
}
