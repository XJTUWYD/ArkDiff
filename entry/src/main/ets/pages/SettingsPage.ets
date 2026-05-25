/**
 * AegisDiff — 设置页（手机端紧凑版）
 */
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SettingsPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('codeFontSize') codeFontSize: number = 14;
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('设置').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
        Row().width(32).height(32)
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      List({ space: 0 }) {
        ListItem() {
          Row() {
            Text('主题').fontSize(14).layoutWeight(1)
            Row() {
              Button('浅').fontSize(11).height(28).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'light' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'light' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 10, right: 10 })
                .onClick(() => { this.colorMode = 'light'; })
              Button('深').fontSize(11).height(28).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'dark' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'dark' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
                .onClick(() => { this.colorMode = 'dark'; })
              Button('自').fontSize(11).height(28).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'auto' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'auto' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
                .onClick(() => { this.colorMode = 'auto'; })
              Button('莫').fontSize(11).height(28).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'monokai' ? '#A6E22E' : '#E8E8E8')
                .fontColor(this.colorMode === 'monokai' ? '#272822' : '#666666')
                .borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
                .onClick(() => { this.colorMode = 'monokai'; })
            }
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
        }

        ListItem() {
          Row() {
            Text('字体').fontSize(14).layoutWeight(1)
            Row() {
              Button('-').fontSize(14).width(28).height(28).type(ButtonType.Circle)
                .backgroundColor('#E8E8E8').fontColor('#333333')
                .onClick(() => { if (this.codeFontSize > 12) this.codeFontSize -= 1; })
              Text(`${this.codeFontSize}`).fontSize(13).fontColor('#666666').width(32).textAlign(TextAlign.Center)
              Button('+').fontSize(14).width(28).height(28).type(ButtonType.Circle)
                .backgroundColor('#E8E8E8').fontColor('#333333')
                .onClick(() => { if (this.codeFontSize < 20) this.codeFontSize += 1; })
            }
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
        }

        ListItem() {
          Row() {
            Text('忽略空白行').fontSize(14).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ignoreBlankLines })
              .onChange((v: boolean) => { this.ignoreBlankLines = v; })
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
        }
      }
      .width(this.isLargeScreen() ? 480 : '100%')
      .layoutWeight(1).backgroundColor('#F5F5F5')

      Column() {
        Text('AegisDiff v1.1.0').fontSize(12).fontColor('#AAAAAA')
        Text('分栏对比 · 三路合并 · 主题切换').fontSize(10).fontColor('#CCCCCC').margin({ top: 4 })
      }
      .width('100%').padding({ top: 12, bottom: 20 })
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
    .alignItems(this.isLargeScreen() ? HorizontalAlign.Center : HorizontalAlign.Start)
  }

  private isLargeScreen(): boolean { return this.currentBp === 'lg' || this.currentBp === 'md'; }
}
