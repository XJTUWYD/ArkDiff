/**
 * AegisDiff — 启动页 SplashPage
 * 展示应用 Logo、简介和快速入口
 */
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SplashPage {
  build() {
    Column() {
      // Logo 区域
      Column() {
        Text('AegisDiff')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1C')
          .margin({ bottom: 8 })

        Text('代码差异对比工具')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ bottom: 4 })

        Text('纯 ArkTS · 离线可用 · 轻量高效')
          .fontSize(13)
          .fontColor('#999999')
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 快速入口按钮
      Button('进入 Diff 编辑')
        .width('80%')
        .height(48)
        .fontSize(16)
        .type(ButtonType.Capsule)
        .backgroundColor('#007AFF')
        .borderRadius(24)
        .onClick(() => {
          router.pushUrl({ url: 'pages/DiffEditorPage' });
        })
        .margin({ bottom: 32 })

      // 底部信息
      Text('v1.0.0 · AegisDiff')
        .fontSize(12)
        .fontColor('#BBBBBB')
        .margin({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
