/**
 * Myers diff engine — C++ 精简版
 *
 * 基于 Eugene Myers "An O(ND) Difference Algorithm and Its Variations"
 * 与 Google diff-match-patch 的 diff_bisect 同源，线性空间变体。
 *
 * 输入: 两个字符串向量 (linesA, linesB)
 * 输出: 编辑操作序列 ('=' 匹配 / '+' 插入 / '-' 删除)
 *       由 NAPI 桥接层转换为 LCS 匹配对返回 ArkTS
 */
#include <vector>
#include <string>
#include <algorithm>

namespace myers {

using Lines = std::vector<std::string>;
using Edits = std::vector<char>; // '=' '+' '-'

// ---------- 回溯：从 trace 快照重建编辑序列 ----------
static Edits backtrack(const std::vector<int*>& trace, int m, int n, int d, int maxV) {
    Edits edits;
    int x = m;
    int y = n;

    for (int depth = d; depth >= 0; depth--) {
        const int* V = trace[depth];
        int k = x - y;
        int maxK = maxV + k;

        int prevK;
        if (k == -depth || (k != depth && V[maxK - 1] < V[maxK + 1])) {
            prevK = k + 1;
        } else {
            prevK = k - 1;
        }

        int prevX = V[maxV + prevK];
        int prevY = prevX - prevK;

        // 对角线上的匹配行
        while (x > prevX && y > prevY) {
            edits.push_back('=');
            x--;
            y--;
        }

        if (depth > 0) {
            if (x == prevX) {
                edits.push_back('+');  // 插入 (B 中有，A 中无)
            } else {
                edits.push_back('-');  // 删除 (A 中有，B 中无)
            }
        }

        x = prevX;
        y = prevY;
    }

    // 回溯出来是倒序，翻转
    std::reverse(edits.begin(), edits.end());
    return edits;
}

/**
 * Myers 最短编辑脚本 — 主算法
 *
 * @param linesA  原始文本行
 * @param linesB  修改后文本行
 * @return        编辑操作序列: '=' 匹配, '+' 插入, '-' 删除
 */
Edits shortestEditScript(const Lines& linesA, const Lines& linesB) {
    int m = static_cast<int>(linesA.size());
    int n = static_cast<int>(linesB.size());

    if (m == 0 || n == 0) {
        return {};
    }

    int maxD = m + n;
    int VSize = 2 * maxD + 1;

    // V[k] = 在对角线 k 上能到达的最远 x 坐标
    std::vector<int> V(VSize, 0);
    // trace: 每一步的 V 快照，用于回溯
    std::vector<int*> trace;

    for (int d = 0; d <= maxD; d++) {
        // 保存当前 V 快照
        int* snapshot = new int[VSize];
        std::copy(V.begin(), V.end(), snapshot);
        trace.push_back(snapshot);

        // 对角线 k: [-d, -d+2, ..., d-2, d]
        for (int k = -d; k <= d; k += 2) {
            int x;
            if (k == -d || (k != d && V[maxD + k - 1] < V[maxD + k + 1])) {
                // 向下移动 (来自 k+1 对角线)
                x = V[maxD + k + 1];
            } else {
                // 向右移动 (来自 k-1 对角线)
                x = V[maxD + k - 1] + 1;
            }

            int y = x - k;

            // 沿对角线贪心前进
            while (x < m && y < n && linesA[x] == linesB[y]) {
                x++;
                y++;
            }

            V[maxD + k] = x;

            // 到达终点 → 找到最短路径
            if (x >= m && y >= n) {
                Edits result = backtrack(trace, m, n, d, maxD);
                // 清理 trace 内存
                for (int* ptr : trace) {
                    delete[] ptr;
                }
                return result;
            }
        }
    }

    // 清理内存（理论上不会到这里）
    for (int* ptr : trace) {
        delete[] ptr;
    }
    return {};
}

} // namespace myers
