module "continuous_apply_codebuild_role" {
    source = "./iam_role"
    name = "continuous-apply"
    identifier = "codebuild.amazonaws.com"
    policy = data.aws_iam_policy.administator_access.policy
}

# 権限不足を避けるため、Adminを付与
data aws_iam_policy "administator_access" {
    arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

################  ワークフロー　#########################
# １．コードを変更したらGitHubにプルリクエスト
# ２．CodeBuildがplanを自動実行
# ３．レビューアはコードとplan結果を確認
# ４．masterブランチへマージしたら、CodeBuildがapplyを自動実行
################  ワークフロー　#########################
resource aws_codebuild_project "continuous_apply" {
    name = "continuous-apply"
    service_role = module.continuous_apply_codebuild_role.iam_role_arn

    # githubを指定
    source {
        type = "GITHUB"
        location = "https://github.com/shiojojo/terraform-devops.git"
    }

    # artifactは作らない
    artifacts {
        type = "NO_ARTIFACTS"
    }

    # buildイメージを指定
    environment {
        type = "LINUX_CONTAINER"
        compute_type = "BUILD_GENERAL1_SMALL"
        image = "hashicorp/terraform:0.12.5"
        privileged_mode = false
    }

    # ビルドイメージにgithubのクレデンシャルの設定
    provisioner "local-exec" {
        command = <<-EOT
        aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --token $GITHUB_TOKEN
        EOT

        # 以下のコマンドで事前設定
        # aws ssm put-parameter --type SecureString --name /continuous_apply/github_token --value "<githubのトークン>"
        environment = {
            GITHUB_TOKEN = data.aws_ssm_parameter.github_token.value
        }
    }
}

data aws_ssm_parameter "github_token" {
    name = "/continuous_apply/github_token"
}

# 自動的にWebhookも作成される
resource aws_codebuild_webhook "continuous_apply" {
    project_name = aws_codebuild_project.continuous_apply.name

    ################ Webhookの条件設定 ################ 
    # プルリクエストの作成
    filter_group {
        filter {
            type = "EVENT"
            pattern = "PULL_REQUEST_CREATED"
        }
    }

    # プルリクエスト更新
    filter_group {
        filter {
            type = "EVENT"
            pattern = "PULL_REQUEST_UPDATED"
        }
    }

    # masterブランチへのpush
    filter_group {
        filter {
            type = "EVENT"
            pattern = "PUSH"
        }

        filter {
            type = "HEAD_REF"
            pattern = "master"
        }
    }
    ################ Webhookの条件設定 ################ 
}