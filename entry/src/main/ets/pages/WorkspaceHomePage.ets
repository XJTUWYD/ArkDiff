/**
 * ArkDiff — WorkspaceHomePage
 * 统一工作台入口，整合核心工作流：
 * 1. 文件比较  2. 目录比较  3. 文本临时比较
 */
import { router } from '@kit.ArkUI';
import { ThemeColors } from '../utils/ThemeColors';
import { AnalyticsService } from '../services/AnalyticsService';

interface WorkflowCard {
  title: string;
  description: string;
  iconResource: Resource;
  route: string;
}

@Entry
@Component
struct WorkspaceHomePage {
  private theme: ThemeColors = ThemeColors.getInstance();
  private workflows: WorkflowCard[] = [
    {
      title: '多标签工作台',
      description: '推荐 · 多标签管理、行内编辑、最近文件，最强对比体验',
      iconResource: $r('sys.symbol.rectangle_stack'),
      route: 'pages/MultiTabDiffPage'
    },
    {
      title: '文件比较',
      description: '打开两个文件进行差异对比，分栏视图 + 行内编辑',
      iconResource: $r('sys.symbol.folder_badge_plus'),
      route: 'pages/FolderDiffPage'
    },
    {
      title: '目录比较',
      description: '对比两个目录中的文件差异，快速定位变更文件',
      iconResource: $r('sys.symbol.folder_badge_plus'),
      route: 'pages/DirectoryDiffPage'
    },
    {
      title: '文本临时比较',
      description: '两侧空栏直接粘贴代码，快速查看差异',
      iconResource: $r('sys.symbol.arrow_clockwise'),
      route: 'pages/DiffEditorPage'
    }
  ];

  build() {
    Column() {
      // 头部
      Column() {
        Text('ArkDiff')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)

        Text('代码差异对比与合并工具')
          .fontSize(14)
          .fontColor(this.theme.textSecondary)
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({ top: 40, bottom: 24 })
      .alignItems(HorizontalAlign.Center)

      // 工作流卡片列表
      Scroll() {
        Column() {
          ForEach(this.workflows, (item: WorkflowCard) => {
            this.WorkflowCard(item)
          })
        }
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)

      // 底部
      Row() {
        Text('v1.0.0')
          .fontSize(12)
          .fontColor(this.theme.textSecondary)

        Blank()

        Row() {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(16)
            .fontColor(['#007AFF'])
            .margin({ right: 4 })
          Text('设置')
            .fontSize(13)
            .fontColor('#007AFF')
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.pageBackground)
  }

  @Builder
  WorkflowCard(item: WorkflowCard) {
    Column() {
      Row() {
        SymbolGlyph(item.iconResource)
          .fontSize(32)
          .fontColor([this.theme.textPrimary])
          .margin({ right: 16 })

        Column() {
          Text(item.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)

          Text(item.description)
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .backgroundColor(this.theme.surfaceBackground)
    .borderRadius(12)
    .margin({ bottom: 12 })
    .onClick(() => {
      // 度量各入口采用度
      const evtMap: Record<string, string> = {
        'pages/MultiTabDiffPage': 'entry_multitab',
        'pages/FolderDiffPage': 'entry_file_compare',
        'pages/DirectoryDiffPage': 'entry_directory_compare',
        'pages/DiffEditorPage': 'entry_text_compare'
      };
      AnalyticsService.track(evtMap[item.route] || 'entry_other');
      router.pushUrl({ url: item.route });
    })
  }
}
