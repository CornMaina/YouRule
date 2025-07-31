#!/usr/bin/env bash

# set -e: 如果任何命令失败，脚本将立即退出
set -e

CONFIG_FILE="config.yml"
OUTPUT_DIR="dist"
TEMP_FILE=$(mktemp) # 创建一个安全的临时文件

# 确保脚本退出时清理临时文件
trap 'rm -f "$TEMP_FILE"' EXIT

# 检查 yq 是否已安装
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install it to proceed." >&2
    exit 1
fi

# 清理并重新创建输出目录
echo "🔥 Cleaning up output directory..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 使用 yq 读取 targets 列表的长度
target_count=$(yq e '.targets | length' "$CONFIG_FILE")
echo "ℹ️ Found $target_count target(s) in $CONFIG_FILE"
echo "----------------------------------------"

# 遍历配置文件中的每一个 target
for i in $(seq 0 $(($target_count - 1))); do
    # 使用 yq 安全地提取输出文件路径和源 URL 列表
    output_file=$(yq e ".targets[$i].output_file" "$CONFIG_FILE")
    header=$(yq e ".targets[$i].header" "$CONFIG_FILE")
    
    echo "▶️ Processing Target: $output_file"

    # 写入自定义头部和更新时间
    echo "$header" > "$output_file"
    echo "# UPDATED: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$output_file"
    echo "" >> "$output_file"

    # 清空临时文件以备下次使用
    > "$TEMP_FILE"

    # 遍历当前 target 的所有 source URL
    sources_count=$(yq e ".targets[$i].sources | length" "$CONFIG_FILE")
    echo "  Downloading $sources_count source(s)..."
    for j in $(seq 0 $(($sources_count - 1))); do
        source_url=$(yq e ".targets[$i].sources[$j]" "$CONFIG_FILE")
        
        # 使用 curl 下载文件内容，并附加到临时文件中
        # -s: 静默模式
        # -L: 跟随重定向
        # --fail: 在 HTTP 错误时失败并退出
        # tee -a: 将输出同时显示在屏幕上并追加到文件
        curl -s -L --fail "$source_url" >> "$TEMP_FILE" || {
          echo "  ❌ ERROR: Failed to download from $source_url" >&2;
          # 决定是否因为一个源失败而中止整个过程
          # exit 1; # 如果需要严格模式，则取消此行注释
        }
    done
    
    echo "  Processing and writing rules..."
    # 处理临时文件：过滤注释、过滤空行、排序、去重，然后追加到最终输出文件
    cat "$TEMP_FILE" | grep -v '^#' | grep -v '^\s*$' | sort -u >> "$output_file"
    
    echo "✅ Finished Target: $output_file"
    echo "----------------------------------------"
done

echo "🎉 All tasks completed successfully!"
