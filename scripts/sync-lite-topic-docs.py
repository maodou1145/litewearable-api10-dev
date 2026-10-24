# -*- coding: utf-8 -*-
"""让 5 篇跨技能共享专题不再「30 份副本靠手改」。

痛点：主题文档被复制到 6 个 skill（api10 / huawei / api6 / reference / hmlwskill / hap-reverse），
      改一处要手动同步 6 处，极易版本漂移。

方案：**单一源 + 一键同步 + 漂移校验**
  - 源目录：`litewearable-api10-dev/references/`（只在这里编辑）
  - 目标：其余 5 个 skill 的 `references/`
  - 用法：
      python sync-lite-topic-docs.py            # 同步（把源覆盖到各处）
      python sync-lite-topic-docs.py --check    # 只校验，不写（CI/自查用）
"""
import hashlib
import io
import os
import shutil
import sys

# __file__ = <skills>/litewearable-api10-dev/scripts/sync-lite-topic-docs.py
#   → 上三级才是 <skills> 根目录
SKILLS_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE_SKILL = 'litewearable-api10-dev'
TOPICS = [
    'network-and-lan.md',
    'size-budget-and-snapshot.md',
    'page-splitting-and-refactor.md',
    'timing-and-interaction-traps.md',
    'verify-workflow.md',
]
TARGETS = [
    'huawei-lite-watch-development',
    'litewearable-reference',
    'hmlwskill',
    'lite-wearable-hap-reverse',
]


def digest(path):
    with open(path, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()[:12]


def main():
    check_only = '--check' in sys.argv
    src_dir = os.path.join(SKILLS_ROOT, SOURCE_SKILL, 'references')
    if not os.path.isdir(src_dir):
        sys.exit('找不到源目录：%s' % src_dir)

    print('源目录: %s' % src_dir)
    print('模式  : %s' % ('仅校验' if check_only else '同步'))
    print()

    drift = 0
    for skill in TARGETS:
        dst_dir = os.path.join(SKILLS_ROOT, skill, 'references')
        if not os.path.isdir(os.path.join(SKILLS_ROOT, skill)):
            print('[%s] 不存在，跳过' % skill)
            continue
        os.makedirs(dst_dir, exist_ok=True)
        rows = []
        for t in TOPICS:
            src = os.path.join(src_dir, t)
            dst = os.path.join(dst_dir, t)
            same = os.path.exists(dst) and digest(src) == digest(dst)
            if not same:
                drift += 1
                if not check_only:
                    shutil.copy2(src, dst)
            rows.append((t, '一致' if same else ('已同步' if not check_only else '漂移')))
        print('[%s]' % skill)
        for t, st in rows:
            print('    %-38s %s' % (t, st))
    print()
    if check_only:
        print('漂移文件数: %d %s' % (drift, '✅ 全一致' if drift == 0 else '⚠️ 请跑一次同步'))
    else:
        print('同步完成（共处理 %d 个文件槽位，其中 %d 处被更新）' % (len(TARGETS) * len(TOPICS), drift))
        print('提示：只在 %s/references/ 里编辑，改完跑本脚本。' % SOURCE_SKILL)


if __name__ == '__main__':
    main()
