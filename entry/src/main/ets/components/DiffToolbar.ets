/**
 * AegisDiff — DiffToolbar 组件（手机端紧凑版）
 */
import { ViewMode } from '../model/DiffModels';

@Component
export struct DiffToolbar {
  @Prop viewMode: ViewMode = ViewMode.SIDE_BY_SIDE;
  @Prop isComputing: boolean = false;
  @Prop searchActive: boolean = false;
  onRunDiff: () => void = () => {};
  onSwitchView: (mode: ViewMode) => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onOpenMerge: () => void = () => {};
  onExport: () => void = () => {};

  @State hoverPaste: boolean = false;
  @State hoverSearch: boolean = false;
  @State hoverMerge: boolean = false;
  @State hoverExport: boolean = false;
  @State hoverSettings: boolean = false;

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

      // 📋 粘贴示例
      Button({ type: ButtonType.Circle }) {
        Text('📋').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onHover((isHover: boolean) => { this.hoverPaste = isHover; })
      .bindPopup(this.hoverPaste, {
        builder: this.tipBuilder('粘贴示例'),
        placement: Placement.Top,
        popupColor: '#333333'
      })
      .onClick(() => { this.onPasteSample(); })

      // 🔍 搜索
      Button({ type: ButtonType.Circle }) {
        Text('🔍').fontSize(14)
      }
      .width(28).height(28)
      .backgroundColor(this.searchActive ? '#007AFF' : Color.Transparent)
      .onHover((isHover: boolean) => { this.hoverSearch = isHover; })
      .bindPopup(this.hoverSearch, {
        builder: this.tipBuilder('搜索'),
        placement: Placement.Top,
        popupColor: '#333333'
      })
      .onClick(() => { this.onToggleSearch(); })

      // 🔀 合并
      Button({ type: ButtonType.Circle }) {
        Text('🔀').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onHover((isHover: boolean) => { this.hoverMerge = isHover; })
      .bindPopup(this.hoverMerge, {
        builder: this.tipBuilder('合并'),
        placement: Placement.Top,
        popupColor: '#333333'
      })
      .onClick(() => { this.onOpenMerge(); })

      // 📤 导出
      Button({ type: ButtonType.Circle }) {
        Text('📤').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onHover((isHover: boolean) => { this.hoverExport = isHover; })
      .bindPopup(this.hoverExport, {
        builder: this.tipBuilder('导出'),
        placement: Placement.Top,
        popupColor: '#333333'
      })
      .onClick(() => { this.onExport(); })

      // ⚙ 设置
      Button({ type: ButtonType.Circle }) {
        Text('⚙').fontSize(14).fontColor('#666666')
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onHover((isHover: boolean) => { this.hoverSettings = isHover; })
      .bindPopup(this.hoverSettings, {
        builder: this.tipBuilder('设置'),
        placement: Placement.Top,
        popupColor: '#333333'
      })
      .onClick(() => { this.onOpenSettings(); })
    }
    .width('100%').height('100%')
    .padding({ left: 4, right: 2 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  tipBuilder(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(Color.White)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
  }
}
