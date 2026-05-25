/**
 * AegisDiff — 设置页
 * 颜色模式、字体大小、忽略空白行
 */
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SettingsPage {
  @State colorMode: string = 'auto';
  @State fontSize: number = 14;
  @State ignoreBlank: boolean = false;

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←').fontSize(20).fontColor('#333333')
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('设置').fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)

        Row().width(36).height(36)
      }
      .width('100%').height(52).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      List({ space: 0 }) {
        ListItem() {
          Row() {
            Text('颜色模式').fontSize(15).layoutWeight(1)
            Row() {
              Button('浅色').fontSize(12).height(30).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'light' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'light' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 12, right: 12 })
                .onClick(() => { this.colorMode = 'light'; })
              Button('深色').fontSize(12).height(30).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'dark' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'dark' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 12, right: 12 }).margin({ left: 8 })
                .onClick(() => { this.colorMode = 'dark'; })
              Button('自动').fontSize(12).height(30).type(ButtonType.Capsule)
                .backgroundColor(this.colorMode === 'auto' ? '#007AFF' : '#E8E8E8')
                .fontColor(this.colorMode === 'auto' ? Color.White : '#666666')
                .borderRadius(10).padding({ left: 12, right: 12 }).margin({ left: 8 })
                .onClick(() => { this.colorMode = 'auto'; })
            }
          }
          .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
        }

        ListItem() {
          Row() {
            Text('代码字体大小').fontSize(15).layoutWeight(1)
            Row() {
              Button('-').fontSize(16).width(32).height(32).type(ButtonType.Circle)
                .backgroundColor('#E8E8E8').fontColor('#333333')
                .onClick(() => { if (this.fontSize > 12) this.fontSize -= 1; })
              Text(`${this.fontSize}`).fontSize(14).fontColor('#666666').width(40).textAlign(TextAlign.Center)
              Button('+').fontSize(16).width(32).height(32).type(ButtonType.Circle)
                .backgroundColor('#E8E8E8').fontColor('#333333')
                .onClick(() => { if (this.fontSize < 20) this.fontSize += 1; })
            }
          }
          .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
        }

        ListItem() {
          Row() {
            Text('忽略空白行').fontSize(15).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ignoreBlank })
              .onChange((v: boolean) => { this.ignoreBlank = v; })
          }
          .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
        }
      }
      .width('100%').layoutWeight(1).backgroundColor('#F5F5F5')

      Column() {
        Text('AegisDiff v1.0.0').fontSize(13).fontColor('#AAAAAA')
        Text('基于 LCS 算法 · 纯 ArkTS 实现').fontSize(12).fontColor('#CCCCCC').margin({ top: 4 })
      }
      .width('100%').padding({ top: 16, bottom: 24 })
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}
