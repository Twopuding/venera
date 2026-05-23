import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 编辑漫画源 .js — 对齐上游 _EditFilePage */
@Entry
@Component
struct ComicSourceEditPage {
  @State sourceKey: string = '';
  @State sourceName: string = '';
  @State content: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.sourceKey = params['sourceKey'] ?? '';
    this.sourceName = params['sourceName'] ?? this.sourceKey;
    this.content = ComicSourceService.getInstance().readScriptContent(this.sourceKey);
  }

  private async saveAndReload(): Promise<void> {
    if (this.sourceKey.length === 0) {
      return;
    }
    this.saving = true;
    ComicSourceService.getInstance().writeScriptContent(this.sourceKey, this.content);
    await ComicSourceService.getInstance().reloadAfterEdit(this.sourceKey);
    this.saving = false;
    try {
      promptAction.showToast({ message: '已保存并重新加载', duration: 2000 });
    } catch (_e) {
      console.info('[ComicSourceEditPage] saved');
    }
    router.back();
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: `${this.sourceName} · ${$r('app.string.edit')}`,
        trailing: () => {
          if (this.saving) {
            LoadingProgress().width(24).height(24)
          }
        }
      })

      TextArea({ text: this.content })
        .layoutWeight(1)
        .margin({ left: 16, right: 16 })
        .fontFamily('monospace')
        .fontSize(12)
        .onChange((v: string) => {
          this.content = v;
        })

      Row({ space: 8 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .onClick(() => router.back())
        Button($r('app.string.save'))
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .enabled(!this.saving)
          .onClick(() => this.saveAndReload())
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
