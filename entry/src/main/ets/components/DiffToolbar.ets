/**
 * AegisDiff — DiffToolbar 组件（手机端紧凑版）
 */
import { ViewMode } from '../model/DiffModels';

@Component
export struct DiffToolbar {
  @Prop viewMode: ViewMode = ViewMode.UNIFIED;
  @Prop isComputing: boolean = false;
  @Prop searchActive: boolean = false;
  onRunDiff: () => void = () => {};
  onSwitchView: (mode: ViewMode) => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onOpenMerge: () => void = () => {};
  onExport: () => void = () => {};

  build() {
    Row() {
      Button(this.isComputing ? '…' : '对比')
        .fontSize(12).height(28)
        .type(ButtonType.Capsule).backgroundColor('#007AFF')
        .borderRadius(14).enabled(!this.isComputing)
        .padding({ left: 10, right: 10 })
        .onClick(() => { this.onRunDiff(); })

      Blank()

      Row() {
        Button('统一')
          .fontSize(11).height(24).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.UNIFIED ? '#007AFF' : '#E0E0E0')
          .fontColor(this.viewMode === ViewMode.UNIFIED ? Color.White : '#666666')
          .borderRadius(0).padding({ left: 6, right: 6 })
          .onClick(() => { this.onSwitchView(ViewMode.UNIFIED); })
        Button('分栏')
          .fontSize(11).height(24).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? '#007AFF' : '#E0E0E0')
          .fontColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? Color.White : '#666666')
          .borderRadius(0).padding({ left: 6, right: 6 })
          .onClick(() => { this.onSwitchView(ViewMode.SIDE_BY_SIDE); })
      }
      .borderRadius(12).border({ width: 1, color: '#D0D0D0' }).clip(true)

      Blank()

      Button({ type: ButtonType.Circle }) {
        Text('P').fontSize(12).fontColor('#007AFF')
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onPasteSample(); })

      Button({ type: ButtonType.Circle }) {
        Text('Q').fontSize(12).fontColor(this.searchActive ? '#FFFFFF' : '#007AFF')
      }
      .width(28).height(28)
      .backgroundColor(this.searchActive ? '#007AFF' : Color.Transparent)
      .onClick(() => { this.onToggleSearch(); })

      Button({ type: ButtonType.Circle }) {
        Text('M').fontSize(11).fontColor('#007AFF')
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onOpenMerge(); })

      Button({ type: ButtonType.Circle }) {
        Text('⇓').fontSize(13).fontColor('#007AFF')
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onExport(); })

      Button({ type: ButtonType.Circle }) {
        Text('⚙').fontSize(14).fontColor('#666666')
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onOpenSettings(); })
    }
    .width('100%').height('100%')
    .padding({ left: 4, right: 2 })
    .backgroundColor('#FFFFFF')
  }
}
