# batch用のCloudWatchLogs
resource aws_cloudwatch_log_group "for_ecs_scheduled_tasks" {
  name              = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}

# batch用のタスク定義
resource aws_ecs_task_definition "example_batch" {
  family                   = "example-batch"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./batch_container_definitions.json") # batch用のコンテナ定義
  # DockerコンテナがCloudWachLogsにログを投げれるように、ECSタスク実行用のIAMロールを追加
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn # IAM Roleの追加　
}

module "ecs_events_role" {
  source     = "./iam_role"
  name       = "ecs-events"
  identifier = "events.amazonaws.com" # CloudWatch イベント
  # CloudWachイベントからECSを起動するためのポリシーを追加
  policy = data.aws_iam_policy.ecs_events_role_policy.policy
}

data aws_iam_policy "ecs_events_role_policy" {
  # CloudWachイベントからECSを起動するためのポリシーを追加
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# CloudWatchイベントルールの定義
resource aws_cloudwatch_event_rule "example_batch" {
  name                = "example-batch"
  description         = "とても重要なバッチ処理です"
  schedule_expression = "cron(*/2 * * * ? *)" # Cron式
}

resource aws_cloudwatch_event_target "example_batch" {
  target_id = "example-batch"
  rule      = aws_cloudwatch_event_rule.example_batch.name # 定義したルール
  role_arn  = module.ecs_events_role.iam_role_arn          # 定義したIAMロール
  arn       = aws_ecs_cluster.example.arn                  # 起動するクラスタ指定 
  # ECSクラスタ上でのを詳細設定
  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    platform_version    = "1.3.0"
    task_definition_arn = aws_ecs_task_definition.example_batch.arn # タスク定義
    network_configuration {
      assign_public_ip = "false" # PublicIp : falise 不要
      subnets          = [aws_subnet.private_0.id]
    }
  }
}