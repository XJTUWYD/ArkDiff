/**
 * AegisDiff — SampleDataProvider
 * 提供预设的 ArkTS 代码对比示例
 */
export class SampleDataProvider {
  static getSampleA(): string {
    return '@Component\nstruct MyButton {\n  @State text: string = \'Click Me\';\n  @State count: number = 0;\n\n  build() {\n    Button(this.text)\n      .width(200)\n      .height(48)\n      .fontSize(16)\n      .backgroundColor(\'#007AFF\')\n      .borderRadius(8)\n      .onClick(() => {\n        this.count++;\n        this.text = \'Clicked \' + this.count;\n      });\n  }\n}';
  }

  static getSampleB(): string {
    return '@Component\nexport struct SmartButton {\n  @Prop label: string = \'Click Me\';\n  @Prop disabled: boolean = false;\n  @State clickCount: number = 0;\n  private onClickCallback?: () => void;\n\n  build() {\n    Button(this.label)\n      .width(\'100%\')\n      .height(48)\n      .fontSize(16)\n      .fontWeight(FontWeight.Medium)\n      .backgroundColor(this.disabled ? \'#CCCCCC\' : \'#007AFF\')\n      .borderRadius(12)\n      .enabled(!this.disabled)\n      .onClick(() => {\n        if (!this.disabled) {\n          this.clickCount++;\n          this.onClickCallback?.();\n        }\n      });\n  }\n}';
  }
}
