#!/bin/sh


# tfnotifyは環境変数CODEBUILD_SOURCE_VERSIONに、pr/123のような文字列が設定されている前提で動きます。
# しかしmasterブランチへプッシュされたとき、この環境変数にはコミットハッシュが設定されます。
# そこで3〜4行目では、直前のコミットメッセージからプルリクエスト番号を取得し、pr/123のような文字列で上書きしています。
MESSAGE=$(git log ${CODEBUILD_SOURCE_VERSION} -1 --pretty=format:"%s")
CODEBUILD_SOURCE_VERSION=$(echo ${MESSAGE} | cut -f4 -d' ' | sed 's/#/pr\//')
# -no-colorオプションでカラー出力を抑制しログを見やすくする
# -auto-approveで実行計画を自動承認
terraform init -input=false -no-color
# tfnotify は実行結果をテンプレートにしたがって実行結果を出力する
terraform apply -input=false -no-color -auto-approve | \
tfnotify --config ${CODEBUILD_SRC_DIR}/tfnotify.yml apply --message "$(date)"
