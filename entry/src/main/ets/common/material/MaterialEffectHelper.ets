import { deviceInfo } from '@kit.BasicServicesKit';
import { hdsMaterial } from '@kit.UIDesignKit';
import { AppConstants } from '../constants/AppConstants';

/**
 * API 23 沉浸光感材质：设备能力查询 + 优雅降级。
 * 参考 HarmonyOS 6.1.0(23) HDS systemMaterialEffect 最佳实践。
 */
export interface SystemMaterialConfig {
  materialType: hdsMaterial.MaterialType;
  materialLevel: hdsMaterial.MaterialLevel;
}

export class MaterialEffectHelper {
  private static immersiveSupported: boolean = false;
  private static initialized: boolean = false;

  static async initialize(): Promise<void> {
    if (MaterialEffectHelper.initialized) {
      return;
    }
    MaterialEffectHelper.initialized = true;
    if (!MaterialEffectHelper.isApi23OrAbove()) {
      MaterialEffectHelper.immersiveSupported = false;
      return;
    }
    try {
      const types: hdsMaterial.MaterialType[] = await hdsMaterial.getSystemMaterialTypes();
      MaterialEffectHelper.immersiveSupported =
        types.includes(hdsMaterial.MaterialType.IMMERSIVE);
    } catch (_e) {
      MaterialEffectHelper.immersiveSupported = false;
    }
  }

  static isApi23OrAbove(): boolean {
    return deviceInfo.sdkApiVersion >= AppConstants.MIN_API_VERSION;
  }

  /**
   * 默认推荐 ADAPTIVE；高端设备可升级为 IMMERSIVE + EXQUISITE。
   */
  static getNavigationMaterial(): SystemMaterialConfig {
    if (!MaterialEffectHelper.isApi23OrAbove()) {
      return {
        materialType: hdsMaterial.MaterialType.NONE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      };
    }
    if (MaterialEffectHelper.immersiveSupported) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      };
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }

  static getTabsMaterial(): SystemMaterialConfig {
    return MaterialEffectHelper.getNavigationMaterial();
  }
}
