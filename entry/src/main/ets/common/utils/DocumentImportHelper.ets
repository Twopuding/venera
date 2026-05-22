import { picker } from '@kit.CoreFileKit';
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
    options.fileSuffixFilters = ['.cbz', '.zip', '.7z', '.cb7'];
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

  static archiveNameFromUri(uri: string): string {
    const base = DocumentImportHelper.folderNameFromUri(uri);
    const dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}
