import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router, promptAction } from '@kit.ArkUI';
import { AppDataService } from '../../common/services/AppDataService';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

/** 关键词屏蔽列表 — 对齐 upstream _ManageBlockingWordView */
@Entry
@Component
struct BlockingWordsPage {
  @State words: string[] = [];
  @State isComment: boolean = false;
  @State pageTitle: Resource = $r('app.string.blocked_words_settings');

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.isComment = params['kind'] === 'comment';
    this.pageTitle = this.isComment ?
      $r('app.string.blocked_comment_words_settings') :
      $r('app.string.blocked_words_settings');
    const settings = AppDataService.getInstance().settings;
    this.words = this.isComment ?
      [...settings.blockedCommentWords] :
      [...settings.blockedWords];
  }

  private async persist(): Promise<void> {
    const settings = AppDataService.getInstance().settings;
    if (this.isComment) {
      settings.blockedCommentWords = [...this.words];
    } else {
      settings.blockedWords = [...this.words];
    }
    await AppDataService.getInstance().save();
  }

  private removeAt(index: number): void {
    this.words.splice(index, 1);
    this.words = [...this.words];
    this.persist();
  }

  private addWord(word: string): void {
    if (word.length === 0) {
      return;
    }
    if (this.words.indexOf(word) >= 0) {
      try {
        promptAction.showToast({ message: $r('app.string.keyword_exists'), duration: 2000 });
      } catch (_e) {
        console.info('[BlockingWords] duplicate keyword');
      }
      return;
    }
    this.words.push(word);
    this.words = [...this.words];
    this.persist();
  }

  build() {
    Column() {
      SecondaryPageHeader({ title: this.pageTitle })

      AddKeywordRow({
        onAdd: (word: string) => this.addWord(word)
      })

      if (this.words.length === 0) {
        Text($r('app.string.blocked_words_empty'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_SECONDARY)
          .padding(16)
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.words, (word: string, index: number) => {
            ListItem() {
              Row() {
                Text(word)
                  .fontSize(16)
                  .fontColor(SysTheme.FONT_PRIMARY)
                  .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(18)
                  .fontColor([SysTheme.FONT_SECONDARY])
                  .onClick(() => this.removeAt(index))
              }
              .width('100%')
              .padding(16)
            }
          }, (word: string) => word)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}

@Component
struct AddKeywordRow {
  @State draft: string = '';
  onAdd?: (word: string) => void;

  build() {
    Row({ space: 8 }) {
      TextInput({ placeholder: $r('app.string.keyword'), text: this.draft })
        .layoutWeight(1)
        .onChange((v: string) => {
          this.draft = v;
        })
      Button($r('app.string.add'))
        .onClick(() => {
          if (this.onAdd) {
            this.onAdd(this.draft.trim());
          }
          this.draft = '';
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }
}
