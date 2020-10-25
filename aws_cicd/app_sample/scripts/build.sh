#!/bin/sh
set -x
# CODEBUILD_SRC_DIRはCodebuildで自動定義されるビルド時に使用されるディレクトリ
if [[ ${CODEBUILD_WEBHOOK_TRIGGER} = 'branch/master' ]]; then
# マスターブランチへのプッシュならapply
# プッシュ時はCODEBUILD_WEBHOOK_TRIGGERはbranch/masterが設定される
  ${CODEBUILD_SRC_DIR}/scripts/apply.sh
else
# プルリクエスト時はplan
# プルリクエスト時はCODEBUILD_WEBHOOK_TRIGGERはpr/<プルリクエスト番号>が設定される
  ${CODEBUILD_SRC_DIR}/scripts/plan.sh
fi
