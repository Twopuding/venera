/**
 * ComicType 工具 — 对齐 upstream lib/foundation/comic_type.dart
 * 网络源 type = sourceKey.hashCode；本地 type = 0
 */
export class ComicTypeUtil {
  static readonly LOCAL_TYPE: number = 0;

  static typeFromSourceKey(sourceKey: string): number {
    if (sourceKey === 'local') {
      return ComicTypeUtil.LOCAL_TYPE;
    }
    return ComicTypeUtil.hashCodeString(sourceKey);
  }

  static sourceKeyFromType(type: number): string {
    if (type === ComicTypeUtil.LOCAL_TYPE) {
      return 'local';
    }
    return '';
  }

  /** 与 Dart String.hashCode 一致的 32 位哈希（收藏 DB type 列） */
  static hashCodeString(s: string): number {
    let hash = 0;
    for (let i = 0; i < s.length; i++) {
      const code = s.charCodeAt(i);
      hash = 0x1fffffff & (hash + code);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash | 0;
  }
}
