import { router, promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import {
  INPUT_DIALOG_REQUEST_KEY,
  INPUT_DIALOG_RESULT_KEY,
  SELECT_DIALOG_REQUEST_KEY,
  SELECT_DIALOG_RESULT_KEY,
  LOADING_VISIBLE_KEY,
  LOADING_ID_KEY
} from '../constants/UiDialogKeys';

/**
 * init.js UI 对话框宿主（API 23 promptAction + 路由页）。
 */
export class JsUiDialogService {
  private static readonly POLL_MS: number = 80;
  private static readonly TIMEOUT_MS: number = 120000;
  private static nextLoadingId: number = 1;

  static async requestInputDialog(title: string): Promise<string | null> {
    const requestId = util.generateRandomUUID(false);
    AppStorage.setOrCreate(INPUT_DIALOG_REQUEST_KEY, requestId);
    AppStorage.setOrCreate(INPUT_DIALOG_RESULT_KEY, '');
    router.pushUrl({
      url: 'pages/common/JsInputDialogPage',
      params: { title: title, requestId: requestId }
    });
    const raw = await JsUiDialogService.pollResult(INPUT_DIALOG_RESULT_KEY, requestId);
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, string | null>;
      const val = parsed['value'];
      return val === null || val === undefined ? null : `${val}`;
    } catch (_e) {
      return null;
    }
  }

  static async requestSelectDialog(title: string, options: string[],
    initialIndex: number): Promise<number | null> {
    if (options.length === 0) {
      return null;
    }
    const requestId = util.generateRandomUUID(false);
    AppStorage.setOrCreate(SELECT_DIALOG_REQUEST_KEY, requestId);
    AppStorage.setOrCreate(SELECT_DIALOG_RESULT_KEY, '');
    router.pushUrl({
      url: 'pages/common/JsSelectDialogPage',
      params: {
        title: title,
        requestId: requestId,
        optionsJson: JSON.stringify(options),
        initialIndex: String(initialIndex)
      }
    });
    const raw = await JsUiDialogService.pollResult(SELECT_DIALOG_RESULT_KEY, requestId);
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, number | null>;
      const idx = parsed['index'];
      return typeof idx === 'number' ? idx : null;
    } catch (_e) {
      return null;
    }
  }

  static async requestDialog(title: string, content: string, actionTexts: string[]): Promise<void> {
    const buttons: promptAction.Button[] = [];
    for (let i = 0; i < actionTexts.length && i < 3; i++) {
      buttons.push({ text: actionTexts[i], color: '#FF0A59F7' });
    }
    if (buttons.length === 0) {
      buttons.push({ text: '确定', color: '#FF0A59F7' });
    }
    try {
      await promptAction.showDialog({
        title: title,
        message: content,
        buttons: buttons
      });
    } catch (e) {
      console.warn(`[JsUiDialogService] showDialog failed: ${e}`);
    }
  }

  static requestShowLoading(): number {
    const id = JsUiDialogService.nextLoadingId++;
    AppStorage.setOrCreate(LOADING_ID_KEY, id);
    AppStorage.setOrCreate(LOADING_VISIBLE_KEY, true);
    return id;
  }

  static requestCancelLoading(id: number): void {
    const current: number | undefined = AppStorage.get(LOADING_ID_KEY) as number | undefined;
    if (current === id || id === 0) {
      AppStorage.setOrCreate(LOADING_VISIBLE_KEY, false);
    }
  }

  private static async pollResult(storageKey: string, requestId: string): Promise<string> {
    const deadline = Date.now() + JsUiDialogService.TIMEOUT_MS;
    while (Date.now() < deadline) {
      await JsUiDialogService.delay(JsUiDialogService.POLL_MS);
      const raw: string | undefined = AppStorage.get(storageKey) as string | undefined;
      if (raw === undefined || raw.length === 0) {
        continue;
      }
      try {
        const parsed = JSON.parse(raw) as Record<string, string>;
        if (`${parsed['requestId']}` === requestId) {
          AppStorage.setOrCreate(storageKey, '');
          return raw;
        }
      } catch (_e) {
        continue;
      }
    }
    return '';
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  static parseActionTexts(actions: Object | undefined): string[] {
    if (!actions || !Array.isArray(actions)) {
      return [];
    }
    const arr = actions as Array<Record<string, Object>>;
    const out: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const t = arr[i]['text'];
      if (t !== undefined) {
        out.push(`${t}`);
      }
    }
    return out;
  }

  static parseStringOptions(options: Object | undefined): string[] {
    if (!options || !Array.isArray(options)) {
      return [];
    }
    const arr = options as Array<Object>;
    const out: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(`${arr[i]}`);
    }
    return out;
  }
}
