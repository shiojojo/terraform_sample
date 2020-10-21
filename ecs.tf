
data aws_iam_policy "ecs_task_execution_role_policy" {
  # AWSで用意されているロール ECSタスク実行用のIAMロール
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSMとKMSを追加　ECSのみを使用する場合は不要。
data aws_iam_policy_document "ecs_task_execution" {
  # source_json は既存のポリシーを継承できる
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source     = "./iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com" # ECSのタスクで使用する。
  # policy = data.aws_iam_policy.ecs_task_execution_role_policy.policy　# ECSタスク実行用のIAMロール
  policy = data.aws_iam_policy_document.ecs_task_execution.json # ECSタスク実行用にSSMとKMS追加
}

module "nginx_sg" {
  source      = "./security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}

resource aws_ecs_cluster "example" {
  name = "example"
}

resource aws_ecs_task_definition "example" {
  family                   = "example" # prefix
  cpu                      = "256"     # cpu 1024 = vCPU 1
  memory                   = "512"     # MB
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]                          # fargateを指定
  container_definitions    = file("./container_definitions.json") # コンテナ定義
  # DockerコンテナがCloudWachLogsにログを投げれるように、ECSタスク実行用のIAMロールを追加
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn # IAM Roleの追加

}


resource aws_ecs_service "example" {
  name                              = "example"
  cluster                           = aws_ecs_cluster.example.arn
  task_definition                   = aws_ecs_task_definition.example.arn
  desired_count                     = 2         # 維持するtask数
  launch_type                       = "FARGATE" # 起動type
  platform_version                  = "1.3.0"   # 使用するバージョンFARGATEのバージョン
  health_check_grace_period_seconds = 60        # 起動時のヘルスチェック

  network_configuration {
    assign_public_ip = false # PublicIp : falise 不要
    security_groups  = [module.nginx_sg.security_group_id]
    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn # load_balaner
    container_name   = "example"                       # container_definitions(コンテナで定義した)の名前
    container_port   = "80"                            # container_definitions(コンテナで定義した)のport
  }

  lifecycle {
    # デプロイのたびにタスクが更新されるので、変更を無視する。
    ignore_changes = [task_definition]
  }

}

resource aws_cloudwatch_log_group "for_ecs" {
  name              = "/ecs/example"
  retention_in_days = 180 # ログの保存期間
}