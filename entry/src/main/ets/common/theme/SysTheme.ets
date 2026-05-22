/**
 * HarmonyOS API 23 系统主题色 Token。
 * 引用 sys.color 分层参数，随系统深浅模式自动切换。
 */
export class SysTheme {
  /** 系统品牌蓝 */
  static readonly BRAND: ResourceColor = $r('sys.color.brand');
  /** 强调文本色（系统蓝） */
  static readonly EMPHASIZE: ResourceColor = $r('sys.color.font_emphasize');
  /** 强调图标色（系统蓝） */
  static readonly ICON_EMPHASIZE: ResourceColor = $r('sys.color.icon_emphasize');
  /** 强调控件背景（系统蓝按钮底） */
  static readonly BACKGROUND_EMPHASIZE: ResourceColor = $r('sys.color.background_emphasize');

  static readonly FONT_PRIMARY: ResourceColor = $r('sys.color.font_primary');
  static readonly FONT_SECONDARY: ResourceColor = $r('sys.color.font_secondary');

  static readonly BACKGROUND_PRIMARY: ResourceColor = $r('sys.color.background_primary');
  static readonly BACKGROUND_SECONDARY: ResourceColor = $r('sys.color.background_secondary');

  /** 底栏选中态 */
  static readonly TAB_SELECTED: ResourceColor = $r('sys.color.ohos_id_color_activated');
  /** 底栏未选中态 */
  static readonly TAB_NORMAL: ResourceColor = $r('sys.color.ohos_id_color_text_secondary');
}
