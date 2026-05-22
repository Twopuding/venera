/**
 * 解析漫画源 source.js 类名（对齐上游 ComicSourceParser）。
 */
export class SourceScriptUtil {
  static extractClassName(script: string): string {
    const normalized = script.replace(/\r\n/g, '\n');
    const lines = normalized.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line.startsWith('class ')) {
        continue;
      }
      if (!line.includes('extends ComicSource')) {
        continue;
      }
      const name = line.split('class')[1].split('extends ComicSource')[0].trim();
      if (name.length > 0) {
        return name;
      }
    }
    return '';
  }
}
