import { SafeAreaInsets } from '../../common/layout/SafeAreaInsets';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ComicSourceService } from '../../common/services/ComicSourceService';
import { ComicSourceDataService } from '../../common/services/ComicSourceDataService';
import { JsEngineBridge } from '../../common/services/JsEngineBridge';
import { JsUiDialogService } from '../../common/services/JsUiDialogService';
import {
  InstalledComicSource,
  SourceAccountConfig,
  SourceSettingDef
} from '../../common/models/ComicModels';
import { DocumentImportHelper } from '../../common/utils/DocumentImportHelper';
import { SemVerUtil } from '../../common/utils/SemVerUtil';
import { SysTheme } from '../../common/theme/SysTheme';
import { SecondaryPageHeader } from '../../common/components/SecondaryPageHeader';

interface SettingSelectOption {
  value: string;
}

/**
 * 漫画源管理 — 1:1 对齐上游 lib/pages/comic_source_page.dart
 */
@Entry
@Component
struct ComicSourcePage {
  @State installed: InstalledComicSource[] = [];
  @State addUrl: string = '';
  @State busy: boolean = false;
  @State checkingUpdates: boolean = false;
  @State panelRefresh: number = 0;

  aboutToAppear(): void {
    this.reloadList();
  }

  onPageShow(): void {
    this.panelRefresh++;
    this.reloadList();
  }

  private async reloadList(): Promise<void> {
    await ComicSourceService.getInstance().ensureEngineReady();
    const stagedKeys = JsEngineBridge.getInstance().getStagedSourceKeys();
    for (let i = 0; i < stagedKeys.length; i++) {
      await ComicSourceService.getInstance().ensureSourceReady(stagedKeys[i]);
    }
    this.installed = await ComicSourceService.getInstance().getInstalledSources();
  }

  private toast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2500 });
    } catch (_e) {
      console.info(`[ComicSourcePage] ${msg}`);
    }
  }

  private async handleAddUrl(): Promise<void> {
    if (this.addUrl.trim().length === 0) {
      return;
    }
    this.busy = true;
    const err = await ComicSourceService.getInstance().addSourceFromUrl(this.addUrl.trim());
    this.busy = false;
    if (err.length > 0) {
      this.toast(err);
      return;
    }
    this.addUrl = '';
    await this.reloadList();
    this.panelRefresh++;
    this.toast('漫画源已添加');
  }

  private async pickJsFile(): Promise<void> {
    const ctx = ComicSourceService.getInstance().getContext();
    if (!ctx) {
      this.toast('应用上下文不可用');
      return;
    }
    const uri = await DocumentImportHelper.pickJsFile(ctx);
    if (!uri) {
      return;
    }
    const content = DocumentImportHelper.readTextFromUri(uri);
    if (content.length === 0) {
      this.toast('无法读取文件');
      return;
    }
    const name = DocumentImportHelper.folderNameFromUri(uri);
    this.busy = true;
    const err = await ComicSourceService.getInstance().addSourceFromScript(content, name);
    this.busy = false;
    if (err.length > 0) {
      this.toast(err);
      return;
    }
    await this.reloadList();
    this.panelRefresh++;
    this.toast('漫画源已添加');
  }

  private async checkUpdates(): Promise<void> {
    this.checkingUpdates = true;
    const count = await ComicSourceService.getInstance().checkComicSourceUpdates();
    this.checkingUpdates = false;
    if (count < 0) {
      this.toast('网络错误');
      return;
    }
    if (count === 0) {
      this.toast('暂无更新');
      await this.reloadList();
      return;
    }
    await this.reloadList();
    this.showUpdatesDialog();
  }

  private showUpdatesDialog(): void {
    const updates = ComicSourceService.getInstance().getAvailableUpdates();
    const lines: string[] = [];
    updates.forEach((ver: string, key: string) => {
      const src = this.installed.find((s: InstalledComicSource) => s.key === key);
      lines.push(`${src?.name ?? key}: ${ver}`);
    });
    promptAction.showDialog({
      title: $r('app.string.updates_available'),
      message: lines.join('\n'),
      buttons: [
        { text: '取消', color: '#999999' },
        { text: '更新', color: '#FF0A59F7' }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.updateAll();
      }
    }).catch(() => {
      // cancelled
    });
  }

  private async updateAll(): Promise<void> {
    this.busy = true;
    const err = await ComicSourceService.getInstance().updateAllAvailable();
    this.busy = false;
    if (err.length > 0) {
      this.toast(err);
    } else {
      this.toast('全部更新完成');
    }
    await this.reloadList();
    this.panelRefresh++;
  }

  private confirmDelete(src: InstalledComicSource): void {
    promptAction.showDialog({
      title: '删除',
      message: `确定删除漫画源「${src.name}」？`,
      buttons: [
        { text: '取消', color: '#999999' },
        { text: '删除', color: '#E53935' }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.doDelete(src.key);
      }
    }).catch(() => {
      // cancelled
    });
  }

  private async doDelete(key: string): Promise<void> {
    this.busy = true;
    await ComicSourceService.getInstance().removeSource(key);
    this.busy = false;
    await this.reloadList();
    this.panelRefresh++;
    this.toast('已删除');
  }

  private async updateOne(src: InstalledComicSource): Promise<void> {
    this.busy = true;
    const err = await ComicSourceService.getInstance().updateSource(src.key);
    this.busy = false;
    if (err.length > 0) {
      this.toast(err);
    } else {
      this.toast('更新完成');
    }
    await this.reloadList();
    this.panelRefresh++;
  }

  private editSource(src: InstalledComicSource): void {
    router.pushUrl({
      url: 'pages/sources/ComicSourceEditPage',
      params: { sourceKey: src.key, sourceName: src.name }
    });
  }

  private hasUpdate(src: InstalledComicSource): boolean {
    return src.pendingVersion.length > 0 &&
      SemVerUtil.isGreater(src.pendingVersion, src.version);
  }

  build() {
    Column() {
      SecondaryPageHeader({
        title: $r('app.string.comic_sources'),
        trailing: () => {
          if (this.busy) {
            LoadingProgress().width(24).height(24)
          }
        }
      })

      Scroll() {
        Column() {
          Text(JsEngineBridge.getInstance().getStatus().runtimeNote)
            .fontSize(12)
            .fontColor(SysTheme.FONT_SECONDARY)
            .padding({ left: 16, right: 16, bottom: 8 })

          this.buildAddCard()

          if (this.installed.length === 0) {
            Text($r('app.string.comic_source_empty_hint'))
              .fontSize(13)
              .fontColor(SysTheme.FONT_SECONDARY)
              .padding(16)
          }

          ForEach(this.installed, (src: InstalledComicSource) => {
            this.buildSourceCard(src)
          }, (src: InstalledComicSource) => `${src.key}_${this.panelRefresh}`)
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .padding(SafeAreaInsets.pagePadding())
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }

  @Builder
  buildAddCard() {
    Column() {
      Text($r('app.string.add_comic_source'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(SysTheme.FONT_PRIMARY)
        .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: 'URL', text: this.addUrl })
          .layoutWeight(1)
          .onChange((v: string) => {
            this.addUrl = v;
          })
          .onSubmit(() => this.handleAddUrl())
        Button() {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([SysTheme.EMPHASIZE])
        }
        .width(40)
        .height(40)
        .enabled(!this.busy)
        .onClick(() => this.handleAddUrl())
      }
      .margin({ top: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        Button($r('app.string.comic_source_list'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => router.pushUrl({ url: 'pages/sources/ComicSourceListPage' }))
        Button($r('app.string.use_config_file'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .margin({ right: 8, bottom: 8 })
          .enabled(!this.busy)
          .onClick(() => this.pickJsFile())
        Button($r('app.string.comic_source_help'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => ComicSourceService.getInstance().openHelpDoc())
        Button(this.checkingUpdates ? '' : $r('app.string.check_updates'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .margin({ right: 8, bottom: 8 })
          .enabled(!this.checkingUpdates && !this.busy)
          .onClick(() => this.checkUpdates())
      }
      .margin({ top: 8 })

      if (ComicSourceService.getInstance().getAvailableUpdates().size > 0) {
        Button($r('app.string.update_all_sources'))
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(12)
          .margin({ top: 4 })
          .enabled(!this.busy)
          .onClick(() => this.updateAll())
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .margin({ left: 16, right: 16, bottom: 8 })
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
    .borderRadius(12)
  }

  @Builder
  buildSourceCard(src: InstalledComicSource) {
    Column() {
      Row() {
        Text(src.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(SysTheme.FONT_PRIMARY)
        Text(src.version)
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ left: 8 })
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
          .borderRadius(8)
        if (this.hasUpdate(src)) {
          Text($r('app.string.new_version'))
            .fontSize(11)
            .fontColor(SysTheme.EMPHASIZE)
            .margin({ left: 6 })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
            .borderRadius(6)
        }
        Blank().layoutWeight(1)
        this.sourceActionIcon($r('sys.symbol.square_and_pencil'), () => this.editSource(src))
        this.sourceActionIcon($r('sys.symbol.arrow_clockwise'), () => this.updateOne(src))
        this.sourceActionIcon($r('sys.symbol.trash'), () => this.confirmDelete(src))
      }
      .width('100%')

      Divider().strokeWidth(0.5).color('#33000000').margin({ top: 8, bottom: 4 })

      SourceSettingsPanel({ sourceKey: src.key, refreshTick: this.panelRefresh })
      SourceAccountPanel({ sourceKey: src.key, sourceName: src.name, refreshTick: this.panelRefresh })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .margin({ left: 16, right: 16, bottom: 8 })
    .backgroundColor(SysTheme.BACKGROUND_SECONDARY)
    .borderRadius(12)
  }

  @Builder
  sourceActionIcon(icon: Resource, onClick: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([SysTheme.FONT_SECONDARY])
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .onClick(onClick)
  }
}

@Component
struct SourceSettingsPanel {
  @Prop sourceKey: string = '';
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @State settings: SourceSettingDef[] = [];
  @State loaded: boolean = false;
  @State callbackBusyKey: string = '';

  aboutToAppear(): void {
    this.loadSettings();
  }

  onRefreshTick(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const defs = await ComicSourceService.getInstance().getSourceSettings(this.sourceKey);
    const svc = ComicSourceService.getInstance();
    for (let i = 0; i < defs.length; i++) {
      defs[i].title = await svc.translateSourceText(this.sourceKey, defs[i].title);
      if (defs[i].buttonText.length > 0) {
        defs[i].buttonText = await svc.translateSourceText(this.sourceKey, defs[i].buttonText);
      }
      for (let j = 0; j < defs[i].options.length; j++) {
        const label = defs[i].options[j].text.length > 0 ? defs[i].options[j].text : defs[i].options[j].value;
        defs[i].options[j].text = await svc.translateSourceText(this.sourceKey, label);
      }
    }
    this.settings = defs;
    this.loaded = true;
  }

  private buildSelectOptions(def: SourceSettingDef): SettingSelectOption[] {
    const out: SettingSelectOption[] = [];
    for (let i = 0; i < def.options.length; i++) {
      const item: SettingSelectOption = {
        value: def.options[i].text.length > 0 ? def.options[i].text : def.options[i].value
      };
      out.push(item);
    }
    return out;
  }

  private selectIndex(def: SourceSettingDef): number {
    const raw = ComicSourceDataService.getInstance().loadSetting(this.sourceKey, def.key);
    const current = raw !== null ? `${raw}` : `${def.defaultValue}`;
    for (let i = 0; i < def.options.length; i++) {
      if (def.options[i].value === current) {
        return i;
      }
    }
    if (def.defaultValue !== undefined && def.defaultValue !== null) {
      for (let i = 0; i < def.options.length; i++) {
        if (def.options[i].value === `${def.defaultValue}`) {
          return i;
        }
      }
    }
    return 0;
  }

  /** 对齐上游 select：展示选项 text 而非原始 value */
  private selectDisplayLabel(def: SourceSettingDef): string {
    const idx = this.selectIndex(def);
    if (idx >= 0 && idx < def.options.length) {
      const opt = def.options[idx];
      return opt.text.length > 0 ? opt.text : opt.value;
    }
    return `${def.defaultValue}`;
  }

  private getSettingDisplay(def: SourceSettingDef): string {
    const raw = ComicSourceDataService.getInstance().loadSetting(this.sourceKey, def.key);
    if (raw !== null) {
      return `${raw}`;
    }
    return `${def.defaultValue}`;
  }

  private async editInputSetting(def: SourceSettingDef): Promise<void> {
    const value = await JsUiDialogService.requestInputDialog(def.title);
    if (value === null) {
      return;
    }
    if (def.validator.length > 0) {
      try {
        const re = new RegExp(def.validator);
        if (!re.test(value)) {
          promptAction.showToast({ message: '输入格式无效', duration: 2000 });
          return;
        }
      } catch (_e) {
        // ignore invalid regex from script
      }
    }
    ComicSourceDataService.getInstance().saveSetting(this.sourceKey, def.key, value);
    await this.loadSettings();
  }

  build() {
    if (!this.loaded || this.settings.length === 0) {
      Column()
    } else {
      Column() {
        ForEach(this.settings, (def: SourceSettingDef) => {
          if (def.type === 'switch') {
            Row() {
              Text(def.title)
                .fontSize(14)
                .fontColor(SysTheme.FONT_PRIMARY)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: ComicSourceDataService.getInstance()
                .loadSetting(this.sourceKey, def.key) === true ||
                (ComicSourceDataService.getInstance().loadSetting(this.sourceKey, def.key) === null &&
                  def.defaultValue === true) })
                .onChange((on: boolean) => {
                  ComicSourceDataService.getInstance().saveSetting(this.sourceKey, def.key, on);
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          } else if (def.type === 'select' && def.options.length > 0) {
            Row() {
              Text(def.title)
                .fontSize(14)
                .fontColor(SysTheme.FONT_PRIMARY)
                .layoutWeight(1)
              Select(this.buildSelectOptions(def))
                .selected(this.selectIndex(def))
                .value(this.selectDisplayLabel(def))
                .onSelect((index: number) => {
                  if (index >= 0 && index < def.options.length) {
                    ComicSourceDataService.getInstance()
                      .saveSetting(this.sourceKey, def.key, def.options[index].value);
                  }
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          } else if (def.type === 'input') {
            Row() {
              Column() {
                Text(def.title)
                  .fontSize(14)
                  .fontColor(SysTheme.FONT_PRIMARY)
                Text(this.getSettingDisplay(def))
                  .fontSize(12)
                  .fontColor(SysTheme.FONT_SECONDARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Row() {
                SymbolGlyph($r('sys.symbol.square_and_pencil'))
                  .fontSize(18)
                  .fontColor([SysTheme.FONT_SECONDARY])
              }
              .width(36)
              .height(36)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.editInputSetting(def))
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          } else if (def.type === 'callback') {
            Row() {
              Text(def.title)
                .fontSize(14)
                .fontColor(SysTheme.FONT_PRIMARY)
                .layoutWeight(1)
              if (this.callbackBusyKey === def.key) {
                LoadingProgress().width(24).height(24)
              } else {
                Button(def.buttonText)
                  .type(ButtonType.Capsule)
                  .height(32)
                  .fontSize(12)
                  .onClick(async () => {
                    this.callbackBusyKey = def.key;
                    const err = await ComicSourceService.getInstance()
                      .runSettingCallback(this.sourceKey, def.key);
                    this.callbackBusyKey = '';
                    if (err.length > 0) {
                      promptAction.showToast({ message: err, duration: 2500 });
                    } else {
                      await this.loadSettings();
                    }
                  })
              }
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          }
        }, (def: SourceSettingDef) => def.key)
      }
      .margin({ top: 4 })
    }
  }
}

@Component
struct SourceAccountPanel {
  @Prop sourceKey: string = '';
  @Prop sourceName: string = '';
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @State account: SourceAccountConfig | null = null;
  @State logged: boolean = false;
  @State reLoginBusy: boolean = false;
  @State canReLogin: boolean = false;
  @State loadingAccount: boolean = true;
  @State engineReady: boolean = true;

  aboutToAppear(): void {
    this.refresh();
  }

  onRefreshTick(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    this.loadingAccount = true;
    const bridge = JsEngineBridge.getInstance();
    this.engineReady = bridge.getStatus().runtimeReady;
    if (!this.engineReady) {
      this.account = null;
      this.loadingAccount = false;
      return;
    }
    await ComicSourceService.getInstance().ensureSourceReady(this.sourceKey);
    this.account = await ComicSourceService.getInstance().getSourceAccount(this.sourceKey);
    this.logged = ComicSourceDataService.getInstance().isLogged(this.sourceKey);
    const stored = ComicSourceDataService.getInstance().loadData(this.sourceKey, 'account');
    this.canReLogin = stored !== null && Array.isArray(stored) && stored.length >= 2;
    this.loadingAccount = false;
  }

  private async openLogin(): Promise<void> {
    try {
      const err = await ComicSourceService.getInstance().openLoginPage(this.sourceKey, this.sourceName);
      if (err.length > 0) {
        promptAction.showToast({ message: err, duration: 2500 });
      }
    } catch (e) {
      promptAction.showToast({ message: `无法打开登录页: ${e}`, duration: 2500 });
    }
  }

  private async doReLogin(): Promise<void> {
    this.reLoginBusy = true;
    const err = await ComicSourceService.getInstance().reLoginSource(this.sourceKey);
    this.reLoginBusy = false;
    if (err.length > 0) {
      promptAction.showToast({ message: err, duration: 2500 });
    } else {
      promptAction.showToast({ message: '登录成功', duration: 1500 });
      await this.refresh();
    }
  }

  build() {
    if (this.loadingAccount) {
      Row() {
        LoadingProgress().width(20).height(20)
        Text('加载账号配置…')
          .fontSize(12)
          .fontColor(SysTheme.FONT_SECONDARY)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ top: 8 })
    } else if (!this.engineReady) {
      Text('QuickJS 未就绪，请重启应用后再登录')
        .fontSize(12)
        .fontColor(SysTheme.FONT_SECONDARY)
        .margin({ top: 8 })
    } else if (!this.account) {
      Column()
    } else if (!this.logged) {
      Row() {
        Text($r('app.string.source_login'))
          .fontSize(14)
          .fontColor(SysTheme.FONT_PRIMARY)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([SysTheme.FONT_SECONDARY])
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })
      .margin({ top: 4 })
      .onClick(() => this.openLogin())
    } else {
      Column() {
        if (this.canReLogin) {
          Row() {
            Column() {
              Text($r('app.string.re_login'))
                .fontSize(14)
                .fontColor(SysTheme.FONT_PRIMARY)
              Text($r('app.string.re_login_hint'))
                .fontSize(11)
                .fontColor(SysTheme.FONT_SECONDARY)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            if (this.reLoginBusy) {
              LoadingProgress().width(24).height(24)
            } else {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(20)
                .fontColor([SysTheme.FONT_SECONDARY])
                .onClick(() => this.doReLogin())
            }
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
        }
        Row() {
          Text($r('app.string.logout'))
            .fontSize(14)
            .fontColor(SysTheme.FONT_PRIMARY)
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(18)
            .fontColor([SysTheme.FONT_SECONDARY])
            .onClick(async () => {
              await ComicSourceService.getInstance().logoutSource(this.sourceKey);
              await this.refresh();
            })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }
      .margin({ top: 4 })
    }
  }
}
