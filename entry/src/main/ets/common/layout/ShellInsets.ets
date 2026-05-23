/**
 * 主壳 / 二级页布局留白与安全区。
 */
export class ShellInsets {
  /** 悬浮页签栏 + barBottomMargin + 渐变遮罩预留高度 (vp) */
  static readonly FLOATING_BAR_RESERVE: number = 108;

  /**
   * 二级页（router @Entry）根 Column 链式 `.padding(SafeAreaInsets.pagePadding())`。
   * 主 Tab 子页在 MainShell 内由 HdsNavigation 处理顶栏，仅需 {@link FLOATING_BAR_RESERVE} 底部留白。
   */
}
