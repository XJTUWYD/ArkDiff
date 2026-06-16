/**
 * Myers diff engine — C++ 精简版
 *
 * 基于 Eugene Myers "An O(ND) Difference Algorithm and Its Variations"。
 *
 * 空间复杂度：O((M+N)·D)（需保留每轮 V 快照用于回溯），
 * 并非论文中的线性空间 middle-snake 变体。对完全相异的大输入（D≈M+N）
 * 内存会显著增长，故在 shortestEditScript 入口设置规模上限 MAX_TOTAL_LINES，
 * 超限时返回空脚本（由上层 ArkTS 回退到 LCS）。
 *
 * trace 快照使用 std::vector<int>（RAII），避免异常路径下裸指针泄漏。
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

// 规模上限：超出后 Myers 的 trace 内存不再可控，交给上层回退
static const int MAX_TOTAL_LINES = 40000;

// ---------- 回溯：从 trace 快照重建编辑序列 ----------
static Edits backtrack(const std::vector<std::vector<int>>& trace, int m, int n, int d, int maxV) {
    Edits edits;
    int x = m;
    int y = n;

    for (int depth = d; depth >= 0; depth--) {
        const std::vector<int>& V = trace[depth];
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
 * @return        编辑操作序列: '=' 匹配, '+' 插入, '-' 删除；输入为空或超限时返回空
 */
Edits shortestEditScript(const Lines& linesA, const Lines& linesB) {
    int m = static_cast<int>(linesA.size());
    int n = static_cast<int>(linesB.size());

    // 边界：一侧为空时按契约输出全删/全增脚本
    if (m == 0 && n == 0) {
        return {};
    }
    if (m == 0) {
        return Edits(static_cast<size_t>(n), '+');
    }
    if (n == 0) {
        return Edits(static_cast<size_t>(m), '-');
    }

    // 规模上限保护：避免 trace 内存 O((M+N)·D) 失控
    if (m + n > MAX_TOTAL_LINES) {
        return {};
    }

    int maxD = m + n;
    int VSize = 2 * maxD + 1;

    // V[k] = 在对角线 k 上能到达的最远 x 坐标
    std::vector<int> V(VSize, 0);
    // trace: 每一步的 V 快照（RAII，无需手动释放）
    std::vector<std::vector<int>> trace;
    trace.reserve(static_cast<size_t>(maxD) + 1);

    for (int d = 0; d <= maxD; d++) {
        // 保存当前 V 快照
        trace.push_back(V);

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
                return backtrack(trace, m, n, d, maxD);
            }
        }
    }

    // 理论上不可达：Myers 保证 d <= m+n 时一定到达终点
    return {};
}

} // namespace myers
