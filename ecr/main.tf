# ECRの作成
resource aws_ecr_repository "example" {
    name = "example"
}

# ECRのライフサイクルのルール
resource aws_ecr_lifecycle_policy "example" {
    repository = aws_ecr_repository.example.name
    # releaseとついたtagが３０日以上たったら、削除する。
    policy = jsonencode(
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 release tagged images",
            "selection": {
                "tagStatus" : "tagged",
                "tagPrefixList" : ["release"]
                "countType" : "imageCountMoreThan",
                "countNumber" : 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
    )
}

# # Docker image push用
# data aws_iam_policy "ecr_container_registry_power_user_role_policy" {
#     # パワーユーザーによる Amazon ECR へのアクセスを許可して、リポジトリへの読み書きアクセスを許可しますが、リポジトリの削除、適用されるポリシードキュメントの変更は許可しません。
#     arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerRegistryPowerUser"
# }

# アーティファクト保存、ビルドログ出力、ECRへの読み書き
# Codebuid用
data aws_iam_policy_document "codebuild" {
    #source_json = data.aws_iam_policy.ecr_container_registry_power_user_role_policy.policy
    statement {
        effect = "Allow"
        resources = ["*"]
        actions = [
            # S3PutObjectPolicy　# アーティファクト保存用
            "s3:PutObject",
            # S3GetObjectPolicy
            "s3:GetObject",
            "s3:GetObjectVersion",
            # CloudWatchLogsPolicy　 # ビルドログ出力用
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            # AmazonEC2ContainerRegistryPowerUser # ECRへの読み書き
            "ecr:GetAuthorizationToken",
			"ecr:BatchCheckLayerAvailability",
			"ecr:GetDownloadUrlForLayer",
			"ecr:GetRepositoryPolicy",
			"ecr:DescribeRepositories",
			"ecr:ListImages",
			"ecr:DescribeImages",
			"ecr:BatchGetImage",
			"ecr:InitiateLayerUpload",
			"ecr:UploadLayerPart",
			"ecr:CompleteLayerUpload",
			"ecr:PutImage"
        ]
    }
}

module "codebuild_role" {
    source = "./iam_role"
    name = "codebuild"
    identifier = "codebuild.amazonaws.com"
    policy = data.aws_iam_policy_document.codebuild.json
}

resource aws_codebuild_project "example" {
    name = "example"
    service_role = module.codebuild_role.iam_role_arn
    source {
        type = "CODEPIPELINE" # CODEPIPELINEと連携
    }
    artifacts {
        type = "CODEPIPELINE" # CODEPIPELINEと連携
    }
    # build環境
    environment {
        type = "LINUX_CONTAINER"
        compute_type = "BUILD_GENERAL1_SMALL"
        # aws管理のビルドイメージ
        image = "aws/codebuild/standard:2.0"
        # dockerコマンドを使用するため、特権を付与
        privileged_mode = true
    }
}

# S3連携、Codebuild操作、ECSへのデプロイ
# Codepipeline用（ECSのデプロイ）
data aws_iam_policy_document "codepipeline" {
    statement {
        effect = "Allow"
        resources = ["*"]
        actions = [
            # S3Policy　# ステージ間でデータを渡す
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            # CodeBuildPolicy #codebuildの操作権限
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            # ECSにDockerイメージをデプロイする権限
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            # ECSPolicy # ECSへデプロイ
            "ecs:DescribeServices",
            "ecs:DescribeTaskDefinition",
            "ecs:DescribeTasks",
            "ecs:ListTasks",
            "ecs:RegisterTaskDefinition",
            "ecs:UpdateService",
            # ECSにロールを付与するPassRole
            "iam:PassRole"
        ]
    }
}

module "codepipeline_role" {
    source = "./iam_role"
    name = "codepipeline"
    identifier = "codepipeline.amazonaws.com"
    policy = data.aws_iam_policy_document.codepipeline.json
}

# Artifact格納用
resource aws_s3_bucket "artifact" {
    bucket = "artifact-pragmatic-terraform-shiotani-20101021"
    lifecycle_rule {
        enabled = true
        expiration {
            days = "180"
        }
    }
    force_destroy = true # オブジェクトがあっても削除できる。
}

resource aws_codepipeline "example" {
    name = "example"
    role_arn = module.codepipeline_role.iam_role_arn

    # GitHubからソースを取得
    stage {
        name = "Source"
        action {
            name = "Source"
            category = "Source"
            owner = "ThirdParty"
            provider = "GitHub" # Githubを指定
            version = 1
            output_artifacts = ["Source"]
            
            configuration = {
                Owner = "shiojojo" # ユーザー名
                Repo = "codepipleintest" #リポジトリ名
                Branch = "master" # ブランチ名
                OAuthToken = "$GITHUB_TOKEN" # GitHubのアクセストークと置き換える。
                PollForSourceChanges = false # Webhookを使用するためポーリングを無効化
            }
        }
    }

    # CodeBuildでビルドする
    stage {
        name = "Build"

        action {
            name = "Build"
            category = "Build"
            owner = "AWS"
            provider = "CodeBuild" # CodeBuildを指定
            version = 1
            input_artifacts = ["Source"]
            output_artifacts = ["Build"]

            configuration = {
                ProjectName = aws_codebuild_project.example.id
            }
        }
    }

    # ECSへDockerイメージをデプロイする
    stage {
        name = "Deploy"

        action {
            name = "Deploy"
            category = "Deploy"
            owner = "AWS"
            provider = "ECS" # #ECS を指定
            version = 1
            input_artifacts = ["Build"]

            configuration = {
                ClusterName = aws_ecs_cluster.example.name
                ServiceName = aws_ecs_service.example.name
                FileName = "imagedefinitions.json"
            }
        }
    }

    # 格納するS3を指定
    artifact_store {
        location = aws_s3_bucket.artifact.id
        type = "S3"
    }
}

# Webhook時の動作
resource aws_codepipeline_webhook "example" {
    name = "example"
    target_pipeline = aws_codepipeline.example.name # Webhook時動作するパイプライン
    target_action = "Source" # 最初にするアクション
    authentication = "GITHUB_HMAC" # GITHUB_HMAC : アクセストークンでの認証
    authentication_configuration {
        secret_token = "VeryRandomStringMoreThan20Byte!" # 20バイト以上のランダムな文字列を秘密鍵として指定
    }
    # 起動条件を記入
    filter {
        json_path = "$.ref"
        match_equals = "refs/heads/{Branch}" # Codepipelineで指定した　Branch = "master"のみ起動
    }
}

##########　Githubの設定　##########　
# githubのリソースを操作するので追加する
provider "github" {
    # クレデンシャルは事前にexportしたGITHUB_TOKENが自動適用される。
    organization = "shiojojo"
}

# githubのWebhook検知
resource github_repository_webhook "example" {
    repository = "codepipleintest"
    configuration {
        url = aws_codepipeline_webhook.example.url
        secret = "VeryRandomStringMoreThan20Byte!" # secret_tokenと同値
        content_type = "json"
        insecure_ssl = false
    }
    events = ["push"] # push時
}

##########　Githubの設定　##########　
