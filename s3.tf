# ALBのログ用
resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic-terraform-shiotani-20201018"
  # ライフサイクルの有効化
  lifecycle_rule {
    enabled = true
    # 破棄するタイミング
    expiration {
      days = "180"
    }
  }
  force_destroy = true # オブジェクトがあっても削除できる。
}

resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect = "Allow"
    # バケットにオブジェクトを追加するアクセス許可を付与します
    actions = ["s3:PutObject"]
    # arn:partition:service:region:account:resource
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]
    # 対象を指定
    principals {
      type        = "AWS"
      identifiers = ["582318560864"] # ELBの東京リージョンのIDを指定
    }
  }
}