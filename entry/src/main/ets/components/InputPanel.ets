/**
 * AegisDiff — InputPanel 组件
 */
@Component
export struct InputPanel {
  @Link textA: string;
  @Link textB: string;

  build() {
    Row() {
      Column() {
        Text('原始代码 (A)')
          .fontSize(12).fontColor('#666666').fontWeight(FontWeight.Medium)
          .padding({ left: 12, top: 8, bottom: 4 }).width('100%')

        TextArea({ text: this.textA, placeholder: '在此粘贴原始代码...' })
          .fontSize(13).fontFamily('monospace')
          .fontColor('#1C1C1C').placeholderColor('#999999')
          .backgroundColor('#FFFFFF').borderRadius(8).padding(8)
          .constraintSize({ minHeight: 100 }).layoutWeight(1)
          .onChange((value: string) => { this.textA = value; })
      }
      .layoutWeight(1).height('100%')
      .padding({ left: 8, right: 4, top: 4, bottom: 4 })

      Column() {
        Text('修改后代码 (B)')
          .fontSize(12).fontColor('#666666').fontWeight(FontWeight.Medium)
          .padding({ left: 12, top: 8, bottom: 4 }).width('100%')

        TextArea({ text: this.textB, placeholder: '在此粘贴修改后代码...' })
          .fontSize(13).fontFamily('monospace')
          .fontColor('#1C1C1C').placeholderColor('#999999')
          .backgroundColor('#FFFFFF').borderRadius(8).padding(8)
          .constraintSize({ minHeight: 100 }).layoutWeight(1)
          .onChange((value: string) => { this.textB = value; })
      }
      .layoutWeight(1).height('100%')
      .padding({ left: 4, right: 8, top: 4, bottom: 4 })
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
  }
}
