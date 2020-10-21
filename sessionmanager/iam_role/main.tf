variable "name" {}
variable "identifier" {}
variable "policy" {}

# assumeRoleで紐づけるサービスを指定
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.identifier]  # 権限を与えるサービス
    }
  }
}

# Roleを作成
resource "aws_iam_role" "default" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Policyを作成
resource "aws_iam_policy" "default" {
  name   = var.name
  policy = var.policy
}

# RoleとPolicyを紐付けassumeから指定したポリシーに変換
resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

output "iam_role_name" {
  value = aws_iam_role.default.name
}
