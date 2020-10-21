resource aws_elasticache_parameter_group "example" {
  name   = "example"
  family = "redis5.0" # エンジン名とメジャーバージョン
  # クラスターモード無効化
  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
}

resource aws_elasticache_subnet_group "example" {
  name = "example"
  subnet_ids = [
    aws_subnet.private_0.id,
    aws_subnet.private_1.id
  ]
}

resource aws_elasticache_replication_group "example" {
  replication_group_id          = "example" # エンドポイントの識別子
  replication_group_description = "Cluster Disabled"
  engine                        = "redis" # エンジン名　memcached OR redis
  engine_version                = "5.0.4" # マイナーバージョンも記載。
  number_cache_clusters         = 3       # primary 1 replica 2
  node_type                     = "cache.t2.micro"
  snapshot_window               = "09:10-10:10"         # UTC 毎日行われる
  snapshot_retention_limit      = 7                     # スナップショット保存期間
  maintenance_window            = "mon:10:40-mon:11:40" # メンテナンスの時間
  automatic_failover_enabled    = true                  # 自動フェルオーバー有効化
  port                          = 6379
  apply_immediately             = false # 設定変更のタイミング　false : 即時, true : メンテナンスウインドウの期間
  security_group_ids            = [module.redis_sg.security_group_id]
  parameter_group_name          = aws_elasticache_parameter_group.example.name
  subnet_group_name             = aws_elasticache_subnet_group.example.name
}

module "redis_sg" {
  source      = "./security_group"
  name        = "redis-sg"
  vpc_id      = aws_vpc.example.id
  port        = 6379
  cidr_blocks = [aws_vpc.example.cidr_block]
}