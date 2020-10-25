#!/bin/sh

# -no-colorオプションでカラー出力を抑制しログを見やすくする
# -input=faleは実行時の入力を抑制、未定義の場合エラーにする
terraform init -input=false -no-color
# tfnotify は実行結果をテンプレートにしたがって実行結果を出力する
terraform plan -input=false -no-color | \
tfnotify --config ${CODEBUILD_SRC_DIR}/tfnotify.yml plan --message "$(date)"
