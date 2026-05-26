/**
 * AegisDiff — ExternalFileOpener（外部文件打开服务）
 *
 * 提供系统级文件操作：
 *   1. 用默认应用打开文件
 *   2. 在系统文件管理器中定位文件
 *   3. 复制文件路径到剪贴板
 *   4. 跨应用分享文件
 *
 * 所有操作均委托 HarmonyOS Want / pasteboard API。
 */
import { fileUri } from '@kit.CoreFileKit';
import pasteboard from '@ohos.pasteboard';
import { wantConstant, Want } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { IconTokens } from '../utils/ThemeTokens';

/** 文件打开模式 */
export enum OpenMode {
  VIEW = 'view',
  EDIT = 'edit',
  SHARE = 'share',
  LOCATE = 'locate', // 在文件管理器中定位
}

/** 文件打开结果 */
export interface OpenResult {
  success: boolean;
  message: string;
  filePath: string;
}

/**
 * ExternalFileOpener
 *
 * 系统外部打开文件，支持：
 * - view:   用默认应用打开（图片、PDF、文档等）
 * - edit:   用编辑器打开（当前 HarmonyOS 不支持直接 edit，降级为 view）
 * - share:  分享到其他应用（通过粘贴板复制路径实现）
 * - locate: 在文件管理器中定位，通过 startAbility 打开沙箱路径
 */
export class ExternalFileOpener {
  /**
   * 打开文件
   */
  static async openFile(filePath: string, mode: OpenMode = OpenMode.VIEW): Promise<OpenResult> {
    try {
      switch (mode) {
        case OpenMode.VIEW:
          return this.viewFile(filePath);
        case OpenMode.EDIT:
          return this.editFile(filePath);
        case OpenMode.LOCATE:
          return this.locateFile(filePath);
        case OpenMode.SHARE:
          return this.shareFile(filePath);
        default:
          return { success: false, message: '不支持的打开模式', filePath };
      }
    } catch (e) {
      return { success: false, message: `${e}`, filePath };
    }
  }

  /**
   * 用默认应用查看文件
   */
  private static async viewFile(filePath: string): Promise<OpenResult> {
    const uri = this.toFileUri(filePath);
    if (!uri) return { success: false, message: '无法获取文件 URI', filePath };

    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uri,
      type: '*/*',
    };

    try {
      const context = this.getContext();
      await context.startAbility(want);
      return { success: true, message: '已打开', filePath };
    } catch (_e) {
      return { success: false, message: '无法打开此文件类型', filePath };
    }
  }

  /**
   * 在默认编辑器中打开（降级为 view）
   */
  private static async editFile(filePath: string): Promise<OpenResult> {
    // HarmonyOS 暂不支持 editData action，降级为 view
    return this.viewFile(filePath);
  }

  /**
   * 在文件管理器中定位文件
   * 使用 ohos.want.action.select UI 不可直接定位，降级为复制路径
   */
  private static async locateFile(filePath: string): Promise<OpenResult> {
    // 复制路径到剪贴板作为替代
    const copyResult = this.copyFilePathToClipboard(filePath);
    return {
      success: copyResult,
      message: copyResult
        ? `${IconTokens.FOLDER_OPEN} 文件路径已复制到剪贴板，请在文件管理器中手动导航`
        : '无法复制路径',
      filePath,
    };
  }

  /**
   * 分享文件路径
   */
  private static async shareFile(filePath: string): Promise<OpenResult> {
    const fileName = filePath.split('/').pop() || 'unknown';
    const shareText = `${fileName}\n路径: ${filePath}`;

    try {
      const shareUrl = this.toFileUri(filePath);
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'text/plain',
        parameters: {
          [wantConstant.Parameter.SHARE_ABSTRACT]: shareText,
          [wantConstant.Parameter.SHARE_TITLE]: `Share ${fileName}`,
        },
        uri: shareUrl || undefined,
      };

      const context = this.getContext();
      await context.startAbility(want);
      return { success: true, message: '分享面板已打开', filePath };
    } catch (_e) {
      // 降级：复制路径
      const copyResult = this.copyFilePathToClipboard(filePath);
      return {
        success: copyResult,
        message: copyResult ? '文件路径已复制到剪贴板' : '分享失败',
        filePath,
      };
    }
  }

  // ==================== 工具方法 ====================

  /**
   * 复制文件路径到系统剪贴板
   */
  static copyFilePathToClipboard(filePath: string): boolean {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, filePath);
      pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (_e) {
      return false;
    }
  }

  /**
   * 复制文件内容到系统剪贴板
   */
  static copyFileContentToClipboard(content: string): boolean {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (_e) {
      return false;
    }
  }

  /**
   * 将沙箱路径转为 file URI
   */
  static toFileUri(sandboxPath: string): string {
    try {
      return fileUri.getUriFromPath(sandboxPath);
    } catch (_e) {
      // 如果是 content URI 或已经是 URI，直接返回
      if (sandboxPath.startsWith('file://') || sandboxPath.startsWith('content://')) {
        return sandboxPath;
      }
      return `file://${sandboxPath}`;
    }
  }

  /**
   * 获取文件名（不含路径）
   */
  static getFileName(filePath: string): string {
    return filePath.split('/').pop() || 'unknown';
  }

  /**
   * 获取文件扩展名
   */
  static getFileExtension(filePath: string): string {
    const name = this.getFileName(filePath);
    const dotIdx = name.lastIndexOf('.');
    return dotIdx === -1 ? '' : name.substring(dotIdx + 1).toLowerCase();
  }

  /**
   * 获取文件所在目录路径
   */
  static getDirectoryPath(filePath: string): string {
    const lastSlash = filePath.lastIndexOf('/');
    return lastSlash === -1 ? '' : filePath.substring(0, lastSlash);
  }

  // ==================== 内部方法 ====================

  /**
   * 获取应用上下文
   */
  private static getContext(): common.UIAbilityContext {
    // HarmonyOS 中通过全局 globalThis 或 getContext 获取
    const ctx = getContext() as common.UIAbilityContext;
    return ctx;
  }
}