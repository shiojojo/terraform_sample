module "mysql_sg" {
  source      = "./security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.example.id
  port        = 3306
  cidr_blocks = [aws_vpc.example.cidr_block]
}

# DBパラメータ
resource aws_db_parameter_group "example" {
  name   = "example"
  family = "mysql5.7" # エンジン名とバージョン
  # mysqlのパラメータ設定
  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
}

# DBオプショングループ
resource aws_db_option_group "example" {
  name                 = "example"
  engine_name          = "mysql"
  major_engine_version = "5.7" # メジャーバージョンを記載
  # オプションを記載
  option {
    option_name = "MARIADB_AUDIT_PLUGIN" # MariaDB監査プラグイン追加
  }
}

# DBサブネットグループの定義
resource aws_db_subnet_group "example" {
  name = "example"
  subnet_ids = [
    aws_subnet.private_0.id,
    aws_subnet.private_1.id
  ]
}

# DBインスタンス
resource aws_db_instance "example" {
  identifier            = "example"
  engine                = "mysql"
  engine_version        = "5.7.25" #パッチバージョン含む
  instance_class        = "db.t3.small"
  allocated_storage     = 20
  max_allocated_storage = 100                     # 最大スケール
  storage_type          = "gp2"                   # gp2 : 汎用SSD
  storage_encrypted     = true                    # 暗号化有効
  kms_key_id            = aws_kms_key.example.arn # kmsの鍵を使用
  username              = "admin"
  password              = "VeryStrongPassword!" # 一時的なパスワードあとで以下のコマンドで変更する。
  # aws rds modify-db-instance --db-instance-identifier 'example' --master-user-password '<password>'
  multi_az                   = true                  # マルチAZ有効化
  publicly_accessible        = false                 # VPC外からのアクセスを遮断
  backup_window              = "09:10-09:40"         # バックアップのタイミング　UTCで設定する。
  backup_retention_period    = 30                    # バックアップ期間
  maintenance_window         = "mon:10:10-mon:10:40" # メンテナンスのタイミング　UTCで設定
  auto_minor_version_upgrade = "false"               # 自動マイナーバージョンアップ無効
  # terraform destroy時はdeletion_protection = false,　skip_final_snapshot = true にする。
  deletion_protection = false # 削除保護 true : 有効化, false : 無効化
  skip_final_snapshot = true  #　インスタンス削除時のスナップショット削除　true: 有効化,　fasle : 無効化
  port                = 3306
  # 一部の設定変更は再起動が伴うことがあるため、falseにする
  apply_immediately      = false # 設定変更のタイミング　true : 即時, false : メンテナンスウインドウ
  vpc_security_group_ids = [module.mysql_sg.security_group_id]
  parameter_group_name   = aws_db_parameter_group.example.name
  option_group_name      = aws_db_subnet_group.example.name
  db_subnet_group_name   = aws_db_subnet_group.example.name
  lifecycle {
    ignore_changes = [password] # passwordはコマンドで変更するため無視する。
  }
}