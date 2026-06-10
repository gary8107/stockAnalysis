#!/bin/bash
# sync_laowang.sh
# 用途：把老王（浦惠投顧 PressPlay）的筆記原檔 王倚隆分析.md 從來源資料夾複製到
#       assets/notes/，再重新產生「獨立的」API 檔 web/api/laowang.json。
# 為什麼獨立於 sync_notes.sh：老王是付費訂閱來源、API 也獨立（/api/laowang.json），
#       與 4 位 YouTube 分析師的 notes.json 管線互不影響，各自更新。
# 使用方式：在 Flutter 專案根目錄執行 ./sync_laowang.sh

set -e  # 任何一步失敗就中止，避免狀態不一致

SOURCE="/Users/wit-gary/Documents/AI_G/分析師筆記"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/assets/notes"

mkdir -p "$DEST"

cp "$SOURCE/王倚隆分析.md" "$DEST/"
echo "✅ Synced 王倚隆分析.md → assets/notes/"

echo
echo "🔨 Regenerating web/api/laowang.json from markdown..."
dart run tool/build_laowang_json.dart
