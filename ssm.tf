# 平文で保存
resource aws_ssm_parameter "db_username" {
  name        = "/db/username"
  value       = "root"
  type        = "String"
  description = "データベースのユーザー名"
}

# # 暗号文で保存、ただしコードに平文が残る。
# resource aws_ssm_parameter "db_raw_password" {
#     name = "/db/raw_password"
#     value = "VeryStrongPassword!"
#     type = "SecureString"
#     description = "データベースのパスワード"
# }

# ダミーのValueをつかってコマンドで後から書き換える。コードに残らない。
resource aws_ssm_parameter "aws_ssm_password" {
  name  = "/db/password"
  value = "uninitialized" # ダミー用の値、以下のコマンドで書き換える。
  # aws ssm put-parameter --name '/db/password' --type SecureString --value 'ModifiedStrongPassword!' --overwrite
  type        = "SecureString"
  description = "データベースのパスワード"
  # コマンドで書き換えるため、valueの値は対象外にする。
  lifecycle {
    ignore_changes = [value]
  }
}