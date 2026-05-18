#!/bin/bash
# sync_notes.sh
# 用途：把分析師筆記原檔（4 個 .md）從來源資料夾複製到 Flutter 專案的 assets/notes/
# 為什麼這麼做：Flutter 只能 bundle 進 assets/ 內的檔案，所以原檔在外面、必須複製進來
# 使用方式：在 Flutter 專案根目錄執行 ./sync_notes.sh

set -e  # 任何一步失敗就中止，避免狀態不一致

SOURCE="/Users/wit-gary/Documents/AI_G/分析師筆記"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/assets/notes"

mkdir -p "$DEST"

# 明確列出 4 個檔案而非用萬用字元，避免意外把其他 .md（如 README）也複製進來
cp "$SOURCE/阮蕙慈分析.md"       "$DEST/"
cp "$SOURCE/李蜀芳分析.md"       "$DEST/"
cp "$SOURCE/陳昆仁分析.md"       "$DEST/"
cp "$SOURCE/分析師對照重點.md" "$DEST/"

echo "✅ Synced 4 notes from 分析師筆記/ to assets/notes/"
ls -la "$DEST"

# Phase 2.5：跑 build script 把 markdown 轉成 web/api/notes.json
# Flutter web 從 JSON 讀資料（不再從 markdown），sync 完必須同步重產
# set -e 已經保證 dart run 失敗會中止整個 sync
echo
echo "🔨 Regenerating web/api/notes.json from markdown..."
dart run tool/build_notes_json.dart
