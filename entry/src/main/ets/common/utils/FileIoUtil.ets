import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 递归删除文件或目录（沙箱路径） */
export class FileIoUtil {
  /** 检查沙箱路径是否存在（避免 statSync 在 async 上下文中产生未捕获原生异常） */
  static existsSync(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (e) {
      const err = e as BusinessError;
      if (err.code === 13900002 || err.code === 13900020) {
        return false;
      }
      return false;
    }
  }

  static deleteRecursive(path: string): void {
    try {
      const stat = fileIo.statSync(path);
      if (stat.isFile()) {
        fileIo.unlinkSync(path);
        return;
      }
      const names = fileIo.listFileSync(path);
      for (let i = 0; i < names.length; i++) {
        FileIoUtil.deleteRecursive(`${path}/${names[i]}`);
      }
      fileIo.rmdirSync(path);
    } catch (_e) {
      // path may already be gone
    }
  }
}
