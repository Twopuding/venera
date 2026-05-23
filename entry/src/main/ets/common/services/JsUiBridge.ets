import { common } from '@kit.AbilityKit';

import { promptAction } from '@kit.ArkUI';

import { LOADING_VISIBLE_KEY, LOADING_ID_KEY } from '../constants/UiDialogKeys';

import { JsUiDialogService } from './JsUiDialogService';



/**

 * init.js UI.* 宿主（API 23）。

 */

export class JsUiBridge {

  private static context?: common.UIAbilityContext;



  static init(context: common.UIAbilityContext): void {

    JsUiBridge.context = context;

    AppStorage.setOrCreate(LOADING_VISIBLE_KEY, false);

    AppStorage.setOrCreate(LOADING_ID_KEY, 0);

  }



  static handle(payload: Record<string, Object>): Object | null {

    const fn = `${payload['function'] ?? ''}`;

    switch (fn) {

      case 'showMessage': {

        const message = `${payload['message'] ?? ''}`;

        if (message.length > 0) {

          JsUiBridge.postToast(message);

        }

        return null;

      }

      case 'launchUrl': {

        const url = `${payload['url'] ?? ''}`;

        if (url.length > 0) {

          JsUiBridge.openUrl(url);

        }

        return null;

      }

      case 'showInputDialog':

      case 'showDialog':

      case 'showSelectDialog':

      case 'showLoading':

      case 'cancelLoading':

        console.warn(`[JsUiBridge] ${fn} 需异步 sendMessage 路径`);

        return null;

      default:

        console.warn(`[JsUiBridge] unknown UI function: ${fn}`);

        return null;

    }

  }



  /** 异步 UI 消息（JsMessageHost.handle 路径） */

  static async handleAsync(payload: Record<string, Object>): Promise<Object | null> {

    const fn = `${payload['function'] ?? ''}`;

    switch (fn) {

      case 'showInputDialog': {

        const title = `${payload['title'] ?? '输入'}`;

        return await JsUiDialogService.requestInputDialog(title);

      }

      case 'showSelectDialog': {

        const title = `${payload['title'] ?? '选择'}`;

        const options = JsUiDialogService.parseStringOptions(payload['options']);

        const initial = typeof payload['initialIndex'] === 'number' ?

          payload['initialIndex'] as number : 0;

        return await JsUiDialogService.requestSelectDialog(title, options, initial);

      }

      case 'showDialog': {

        const title = `${payload['title'] ?? ''}`;

        const content = `${payload['content'] ?? ''}`;

        const actions = JsUiDialogService.parseActionTexts(payload['actions']);

        await JsUiDialogService.requestDialog(title, content, actions);

        return null;

      }

      case 'showLoading': {

        const id = JsUiDialogService.requestShowLoading();

        return id;

      }

      case 'cancelLoading': {

        const id = typeof payload['id'] === 'number' ? payload['id'] as number : 0;

        JsUiDialogService.requestCancelLoading(id);

        return null;

      }

      default:

        return JsUiBridge.handle(payload);

    }

  }



  private static postToast(message: string): void {

    setTimeout(() => {

      try {

        promptAction.showToast({ message: message, duration: 2000 });

      } catch (e) {

        console.info(`[JsUiBridge] ${message}`);

      }

    }, 0);

  }



  private static openUrl(url: string): void {

    const ctx = JsUiBridge.context;

    if (!ctx) {

      console.warn(`[JsUiBridge] no context for launchUrl: ${url}`);

      return;

    }

    setTimeout(() => {

      ctx.openLink(url, { appLinkingOnly: false }).catch((e: Error) => {

        console.error(`[JsUiBridge] openLink failed: ${e}`);

      });

    }, 0);

  }

}


