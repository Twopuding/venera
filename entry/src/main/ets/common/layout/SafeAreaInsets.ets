/** AppStorage keys for window avoid-area heights (vp). */
export const SAFE_AREA_TOP_VP_KEY = 'safeAreaTopVp';
export const SAFE_AREA_BOTTOM_VP_KEY = 'safeAreaBottomVp';

/**
 * 全屏窗口下二级页根 Column 的内边距（状态栏 + 导航/手势条）。
 * 数值由 EntryAbility 在窗口创建后写入 AppStorage。
 */
export class SafeAreaInsets {
  static pagePadding(): Padding {
    const top = AppStorage.get<number>(SAFE_AREA_TOP_VP_KEY) ?? 0;
    const bottom = AppStorage.get<number>(SAFE_AREA_BOTTOM_VP_KEY) ?? 0;
    return { top: top, bottom: bottom };
  }
}
