/**
 * AegisDiff — DiffToolbar 组件
 */
import { ViewMode } from '../model/DiffModels';

@Component
export struct DiffToolbar {
  @Prop viewMode: ViewMode = ViewMode.UNIFIED;
  @Prop isComputing: boolean = false;
  onRunDiff: () => void = () => {};
  onSwitchView: (mode: ViewMode) => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};

  build() {
    Row() {
      Button(this.isComputing ? '...' : '执行对比')
        .fontSize(13).height(32)
        .type(ButtonType.Capsule).backgroundColor('#007AFF')
        .borderRadius(16).enabled(!this.isComputing)
        .padding({ left: 12, right: 12 })
        .onClick(() => { this.onRunDiff(); })

      Blank()

      Row() {
        Button('统一')
          .fontSize(12).height(28).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.UNIFIED ? '#007AFF' : '#E0E0E0')
          .fontColor(this.viewMode === ViewMode.UNIFIED ? Color.White : '#666666')
          .borderRadius(0).padding({ left: 10, right: 10 })
          .onClick(() => { this.onSwitchView(ViewMode.UNIFIED); })

        Button('分栏')
          .fontSize(12).height(28).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? '#007AFF' : '#E0E0E0')
          .fontColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? Color.White : '#666666')
          .borderRadius(0).padding({ left: 10, right: 10 })
          .onClick(() => { this.onSwitchView(ViewMode.SIDE_BY_SIDE); })
      }
      .borderRadius(14).border({ width: 1, color: '#D0D0D0' }).clip(true)

      Blank()

      Button({ type: ButtonType.Circle }) {
        Text('P').fontSize(14).fontColor('#007AFF')
      }
      .width(32).height(32).backgroundColor(Color.Transparent)
      .onClick(() => { this.onPasteSample(); })

      Button({ type: ButtonType.Circle }) {
        Text('*').fontSize(20).fontColor('#666666')
      }
      .width(32).height(32).backgroundColor(Color.Transparent)
      .onClick(() => { this.onOpenSettings(); })
    }
    .width('100%').height('100%')
    .padding({ left: 12, right: 8 })
    .backgroundColor('#FFFFFF')
  }
}
