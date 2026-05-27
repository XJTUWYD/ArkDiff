/**
 * AegisDiff — WorkspaceHomePage
 * 统一工作台入口，整合三大核心工作流：
 * 1. 文件比较  2. 目录比较  3. 三路合并  4. 文本临时比较
 */
import { router } from '@kit.ArkUI';
import { ThemeColors } from '../utils/ThemeColors';

interface WorkflowCard {
  title: string;
  description: string;
  icon: string;
  route: string;
}

@Entry
@Component
struct WorkspaceHomePage {
  private theme: ThemeColors = ThemeColors.getInstance();
  private workflows: WorkflowCard[] = [
    {
      title: '文件比较',
      description: '打开两个文件进行差异对比，支持统一视图和分栏视图',
      icon: '⊞',
      route: 'pages/FolderDiffPage'
    },
    {
      title: '目录比较',
      description: '对比两个目录中的文件差异，快速定位变更文件',
      icon: '⊟',
      route: 'pages/DirectoryDiffPage'
    },
    {
      title: '三路合并',
      description: '基于共同祖先的三方合并，可视化解决冲突',
      icon: '⧖',
      route: 'pages/MergePage'
    },
    {
      title: '文本临时比较',
      description: '粘贴两段文本快速查看差异',
      icon: '≡',
      route: 'pages/DiffEditorPage'
    }
  ];

  build() {
    Column() {
      // 头部
      Column() {
        Text('AegisDiff')
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

        Text('⛭ 设置')
          .fontSize(13)
          .fontColor('#007AFF')
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
        Text(item.icon)
          .fontSize(32)
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
      router.pushUrl({ url: item.route });
    })
  }
}
