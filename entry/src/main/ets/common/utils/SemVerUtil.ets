/**
 * 语义化版本比较 — 对齐上游 comic_source/parser.dart compareSemVer。
 * @returns true 当 ver1 > ver2
 */
export class SemVerUtil {
  static isGreater(ver1: string, ver2: string): boolean {
    let v1 = ver1.replace('-', '.');
    let v2 = ver2.replace('-', '.');
    const p1 = v1.split('.');
    const p2 = v2.split('.');
    for (let i = 0; i < 3; i++) {
      const n1 = parseInt(p1[i] ?? '0', 10);
      const n2 = parseInt(p2[i] ?? '0', 10);
      if (n1 > n2) {
        return true;
      }
      if (n1 < n2) {
        return false;
      }
    }
    const v14 = p1.length > 3 ? p1[3] : undefined;
    const v24 = p2.length > 3 ? p2[3] : undefined;
    if (v14 === v24) {
      return false;
    }
    if (v14 === undefined && v24 !== 'hotfix') {
      return true;
    }
    if (v14 === undefined) {
      return false;
    }
    if (v24 === undefined) {
      return v14 === 'hotfix';
    }
    return v14 > v24;
  }
}
