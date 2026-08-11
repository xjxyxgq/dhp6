```bash
#!/bin/bash

# ============================================================
# rsync 文件同步脚本
#
# 功能：
#   1. 按 mtime 筛选文件
#   2. 按文件名匹配 abc-*.log
#   3. 递归同步
#   4. rsync 限速 20 MiB/s
#   5. 不删除源文件
#   6. 支持 dry-run
#
# 使用：
#   ./rsync_filter.sh
#   ./rsync_filter.sh --dry-run
# ============================================================

set -u

# -----------------------------
# 配置
# -----------------------------

# 源目录
SOURCE="/data/source"

# 目标目录
DEST="/data/backup"

# 文件名匹配规则
FILE_PATTERN="abc-*.log"

# 只同步这个时间之后修改的文件
CUTOFF_TIME="2025-01-01 00:00:00"

# rsync 限速
# 单位：KiB/s
# 20480 KiB/s = 20 MiB/s
BWLIMIT=20480

# 日志文件
LOG_FILE="./rsync_filter_$(date '+%Y%m%d_%H%M%S').log"

# 默认不使用 dry-run
DRY_RUN=0


# -----------------------------
# 参数处理
# -----------------------------

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi


# -----------------------------
# 基础检查
# -----------------------------

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: 源目录不存在: $SOURCE"
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "目标目录不存在，创建: $DEST"

    if ! mkdir -p "$DEST"; then
        echo "ERROR: 无法创建目标目录: $DEST"
        exit 1
    fi
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo "ERROR: rsync 未安装"
    exit 1
fi

if ! command -v find >/dev/null 2>&1; then
    echo "ERROR: find 不存在"
    exit 1
fi


# -----------------------------
# 输出配置
# -----------------------------

echo "========================================"
echo "rsync 文件同步"
echo "========================================"
echo "源目录       : $SOURCE"
echo "目标目录     : $DEST"
echo "文件匹配     : $FILE_PATTERN"
echo "mtime >      : $CUTOFF_TIME"
echo "限速         : ${BWLIMIT} KiB/s"
echo "模式         : $([ "$DRY_RUN" -eq 1 ] && echo "DRY-RUN" || echo "正式同步")"
echo "日志         : $LOG_FILE"
echo "========================================"


# -----------------------------
# 检查时间格式
# -----------------------------

if ! date -d "$CUTOFF_TIME" '+%s' >/dev/null 2>&1; then
    echo "ERROR: 时间格式错误: $CUTOFF_TIME"
    exit 1
fi


# -----------------------------
# 生成文件列表并同步
#
# -newermt:
#   mtime > 指定时间
#
# -name:
#   匹配 abc-*.log
#
# -print0:
#   使用 NULL 分隔，避免文件名中空格、
#   引号、特殊字符导致解析错误
# -----------------------------

RSYNC_OPTIONS=(
    -a
    -v
    --from0
    --files-from=-
    --bwlimit="$BWLIMIT"
    --human-readable
)

if [ "$DRY_RUN" -eq 1 ]; then
    RSYNC_OPTIONS+=(--dry-run)
fi


echo
echo "开始查找文件..."
echo


find "$SOURCE" \
    -type f \
    -name "$FILE_PATTERN" \
    -newermt "$CUTOFF_TIME" \
    -print0 |
while IFS= read -r -d '' FILE; do

    # 转换成相对于 SOURCE 的路径
    RELATIVE_PATH="${FILE#"$SOURCE"/}"

    printf '%s\0' "$RELATIVE_PATH"

done |
tee >(tr '\0' '\n' >> "$LOG_FILE") |
rsync "${RSYNC_OPTIONS[@]}" \
    "$SOURCE/" \
    "$DEST/"


RET=$?


echo
echo "========================================"

if [ "$RET" -eq 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN 完成，没有实际复制文件。"
    else
        echo "同步完成。"
        echo "源文件不会被删除。"
    fi
else
    echo "同步失败，rsync 返回码: $RET"
fi

echo "========================================"

exit "$RET"
```

