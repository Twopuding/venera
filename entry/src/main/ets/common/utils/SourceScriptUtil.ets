/** 从 source.js 静态解析出的元数据 */
export interface ParsedSourceMeta {
  key: string;
  name: string;
  version: string;
  url: string;
  minAppVersion: string;
}

/**
 * 解析漫画源 source.js（对齐上游 ComicSourceParser）。
 */
export class SourceScriptUtil {
  static extractClassName(script: string): string {
    const normalized = script.replace(/\r\n/g, '\n');
    const match = normalized.match(/class\s+(\w+)\s+extends\s+ComicSource\b/);
    if (match && match[1]) {
      return match[1];
    }
    return '';
  }

  /**
   * 不依赖 QuickJS，从类字段赋值解析 name/key/version（官方 venera-configs 格式）。
   */
  static parseMetaFromScript(script: string): ParsedSourceMeta | null {
    const className = SourceScriptUtil.extractClassName(script);
    if (className.length === 0) {
      return null;
    }
    const classIdx = script.indexOf(`class ${className}`);
    const slice = classIdx >= 0 ? script.substring(classIdx) : script;
    const key = SourceScriptUtil.extractAssignString(slice, 'key');
    const name = SourceScriptUtil.extractAssignString(slice, 'name');
    let version = SourceScriptUtil.extractAssignString(slice, 'version');
    const url = SourceScriptUtil.extractAssignString(slice, 'url');
    const minAppVersion = SourceScriptUtil.extractAssignString(slice, 'minAppVersion');
    if (key.length === 0 || name.length === 0) {
      return null;
    }
    if (version.length === 0) {
      version = '1.0.0';
    }
    const meta: ParsedSourceMeta = {
      key: key,
      name: name,
      version: version,
      url: url,
      minAppVersion: minAppVersion
    };
    return meta;
  }

  private static extractAssignString(text: string, field: string): string {
    const dq = new RegExp(`\\b${field}\\s*=\\s*"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"`);
    const sq = new RegExp(`\\b${field}\\s*=\\s*'([^'\\\\]*(?:\\\\.[^'\\\\]*)*)'`);
    const m1 = text.match(dq);
    if (m1 && m1[1]) {
      return SourceScriptUtil.unescapeJsString(m1[1]);
    }
    const m2 = text.match(sq);
    if (m2 && m2[1]) {
      return SourceScriptUtil.unescapeJsString(m2[1]);
    }
    return '';
  }

  private static unescapeJsString(s: string): string {
    return s.replace(/\\n/g, '\n').replace(/\\r/g, '\r').replace(/\\t/g, '\t')
      .replace(/\\'/g, '\'').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
  }
}
