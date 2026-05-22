import { MainShell } from './main/MainShell';
import { SysTheme } from '../common/theme/SysTheme';

@Entry
@Component
struct Index {
  build() {
    Column() {
      MainShell()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SysTheme.BACKGROUND_PRIMARY)
  }
}
