# カスタマーマスターキーの設定
resource aws_kms_key "example" {
  description             = "Example Customer Master Key"
  enable_key_rotation     = true # 自動ローテーション有効化
  is_enabled              = true # カスタマーキー有効化
  deletion_window_in_days = 30   # カスタマーキー削除待機時間
}

# kmsのエイリアス
resource aws_kms_alias "example" {
  name          = "alias/example" # 「alias/」 が必須
  target_key_id = aws_kms_key.example.key_id
}