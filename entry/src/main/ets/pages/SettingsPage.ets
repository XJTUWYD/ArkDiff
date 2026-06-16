/**
 * AegisDiff — 设置页（手机端紧凑版）
 */
import { router, promptAction } from '@kit.ArkUI';
import { AnalyticsService } from '../services/AnalyticsService';

@Entry
@Component
struct SettingsPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('codeFontSize') codeFontSize: number = 14;
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @StorageLink('ignoreCase') ignoreCase: boolean = false;
  @StorageLink('ignoreWhitespace') ignoreWhitespace: boolean = false;
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @State statsVersion: number = 0;

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(18).fontColor(['#333333']) }
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

        ListItem() {
          Row() {
            Text('忽略大小写').fontSize(14).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ignoreCase })
              .onChange((v: boolean) => { this.ignoreCase = v; })
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
        }

        ListItem() {
          Row() {
            Text('忽略行首尾空白').fontSize(14).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ignoreWhitespace })
              .onChange((v: boolean) => { this.ignoreWhitespace = v; })
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
        }

        // 使用统计（本地透明可查，不上传）
        ListItem() {
          Row() {
            Column() {
              Text('使用统计').fontSize(14)
              Text('本地记录，可随时查看或清除').fontSize(10).fontColor('#999').margin({ top: 2 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(`${this.totalEventCount()} 次`).fontSize(11).fontColor('#666')
          }
          .width('100%').height(48).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
          .onClick(() => { this.showAnalytics(); })
        }
      }
      .width(this.isLargeScreen() ? 480 : '100%')
      .layoutWeight(1).backgroundColor('#F5F5F5')

      Column() {
        Text('ArkDiff v1.1.0').fontSize(12).fontColor('#AAAAAA')
        Text('分栏对比 · 字符级差异 · 主题切换').fontSize(10).fontColor('#CCCCCC').margin({ top: 4 })
      }
      .width('100%').padding({ top: 12, bottom: 20 })
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
    .alignItems(this.isLargeScreen() ? HorizontalAlign.Center : HorizontalAlign.Start)
  }

  private isLargeScreen(): boolean { return this.currentBp === 'lg' || this.currentBp === 'md'; }

  /** 事件总次数（用于列表行展示；读取 statsVersion 以便清除后刷新） */
  private totalEventCount(): number {
    const _ = this.statsVersion;
    const counts = AnalyticsService.getCounts();
    let sum = 0;
    const keys = Object.keys(counts);
    for (const k of keys) sum += counts[k];
    return sum;
  }

  /** 展示统计详情 + 最近错误，并支持清除 */
  private showAnalytics(): void {
    const counts = AnalyticsService.getCounts();
    const entries: string[][] = [];
    const keys = Object.keys(counts);
    for (const k of keys) entries.push([k, String(counts[k])]);
    // 按次数降序
    entries.sort((a, b) => Number(b[1]) - Number(a[1]));
    const top = entries.slice(0, 12);
    const eventsText = top.length > 0
      ? top.map(e => `• ${e[0]}: ${e[1]}`).join('\n')
      : '暂无数据';

    const errs = AnalyticsService.getErrors();
    const errText = errs.length > 0
      ? errs.slice(0, 5).map(e => `• [${e.scope}] ${e.message}`).join('\n')
      : '无';

    AlertDialog.show({
      title: '使用统计（本地）',
      message: `【功能使用】\n${eventsText}\n\n【最近错误】\n${errText}\n\n注：所有数据仅存于本机，不上传。`,
      autoCancel: true,
      primaryButton: {
        value: '清除统计',
        action: (): void => {
          AnalyticsService.reset();
          this.statsVersion++;
          this.toast('已清除统计');
        }
      },
      secondaryButton: {
        value: '关闭',
        action: (): void => {}
      }
    });
  }

  private toast(msg: string): void {
    try { promptAction.showToast({ message: msg, duration: 2000 }); } catch (_e) { /* ignore */ }
  }
}
