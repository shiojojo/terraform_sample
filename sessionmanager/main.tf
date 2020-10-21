# SessionManager用に定義されているAmazonSSMManagedInstanceCoreポリシーをベースにする
data aws_iam_policy "ec2_for_ssm" {
    arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data aws_iam_policy_document "ec2_for_ssm" {
    source_json = data.aws_iam_policy.ec2_for_ssm.policy

    statement {
        effect = "Allow"
        resources = ["*"]

        actions = [
            # S3の書き込み
            "s3:PutObject",
            "logs:PutLogEvents",
            # logsへの書き込み
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            # ecrへの参照
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            # ssmのパラメーター取得
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParametersByPath",
            # kmsの復号化
            "kms:Decrypt",
        ]
    }
}

module "ec2_for_ssm_role" {
    source = "./iam_role"
    name = "ec2-for-ssm"
    identifier = "ec2.amazonaws.com"
    policy = data.aws_iam_policy_document.ec2_for_ssm.json
}

# EC2はロールプロファイルに結びつける必要あり
resource aws_iam_instance_profile "ec2_for_ssm" {
    name = "ec2-for-ssm"
    role = module.ec2_for_ssm_role.iam_role_name
}

# Seesion Manager用のEC２
resource aws_instance "example_for_operation" {
    ami = "ami-0ce107ae7af2e92b5" # AmazonLinux 2
    instance_type = "t3.micro"
    iam_instance_profile = aws_iam_instance_profile.ec2_for_ssm.name # EC2はインスタンスプロファイル
    subnet_id = aws_subnet.private_0.id
    user_data = file("./user_data.sh") # docker install用
}

# Session Managerの操作ログ保存用
resource aws_s3_bucket "operation" {
    bucket = "operation-pragmatic-terraform-shiotani-20201021"

    lifecycle_rule {
        enabled = true

        expiration {
            days = "180"
        }
    }
    force_destroy = true # オブジェクトがあっても削除できる。
}

# CloudWachLogs
resource aws_cloudwatch_log_group "operation" {
    name = "/operation"
    retention_in_days = 180
}


resource aws_ssm_document "session_manager_run_shell" {
     # SSM-SessionManagerRunShellにするとAWS CLIの時オプション指定を省略できる
    name = "SSM-SessionManagerRunShell"
    document_type = "Session" # Session Managerはこの値は固定
    document_format = "JSON" # Session Managerはこの値は固定

    content = jsonencode(
        {
            "schemaVersion" : "1.0",
            "description" : "Document to hold regional settings for Session Manager",
            "sessionType" : "Standard_Stream",
            # logの保存先
            "inputs" : {
                "s3BucketName" : "${aws_s3_bucket.operation.id}"
                "cloudWatchLogGroupName" : "${aws_cloudwatch_log_group.operation.name}"
            }
        }
    )
}

output "operation_instance_id" {
    value = aws_instance.example_for_operation.id
}