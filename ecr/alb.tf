module "http_sg" {
    source = "./security_group"
    name = "http-sg"
    vpc_id = aws_vpc.example.id
    port = 80
    cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
    source = "./security_group"
    name = "https-sg"
    vpc_id = aws_vpc.example.id
    port = 443
    cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
    source = "./security_group"
    name = "http-redirect-sg"
    vpc_id = aws_vpc.example.id
    port = 8080
    cidr_blocks = ["0.0.0.0/0"]
}

resource aws_lb "example" {
    name = "example"
    load_balancer_type = "application"  # ALB : application , NLB : network
    internal = false                    
    idle_timeout = 60
    enable_deletion_protection = false   # 削除保護 true : 保護　false : 保護しない
    subnets = [
        aws_subnet.public_0.id,
        aws_subnet.public_1.id,
    ]
    access_logs {
        bucket = aws_s3_bucket.alb_log.id
        enabled = true
    }
    security_groups = [
        module.http_sg.security_group_id,
        module.https_sg.security_group_id,
        module.http_redirect_sg.security_group_id,
    ]
}

resource aws_lb_listener "http" {
    # ALBのarnを指定します。
    #XXX: arnはAmazon Resource Names の略で、リソースを特定するための一意な名前(id)
    load_balancer_arn = aws_lb.example.arn
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "fixed-response" # 固定のhttpレスポンス
        fixed_response {
            content_type = "text/plain"
            message_body = "これは「ｈｔｔｐ」です。"
            status_code = "200"
        }
    }
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
}

resource aws_lb_listener "https" {
    # ALBのarnを指定します。
    #XXX: arnはAmazon Resource Names の略で、リソースを特定するための一意な名前(id)
    load_balancer_arn = aws_lb.example.arn
    port = "443"
    protocol = "HTTPS"
    certificate_arn = aws_acm_certificate.example.arn # SSL証明書の指定
    ssl_policy = "ELBSecurityPolicy-2016-08" #AWSの推奨ポリシー

    default_action {
        type = "fixed-response" # 固定のhttpレスポンス
        fixed_response {
            content_type = "text/plain"
            message_body = "これは「ｈｔｔｐｓ」です。"
            status_code = "200"
        }
    }
}

resource aws_lb_listener "redirect_http_to_https" {
    # ALBのarnを指定します。
    #XXX: arnはAmazon Resource Names の略で、リソースを特定するための一意な名前(id)
    load_balancer_arn = aws_lb.example.arn
    port = "8080"
    protocol = "HTTP"

    default_action {
        type = "redirect" # リダイレクト
        redirect {
            port = "443"
            protocol = "HTTPS"
            status_code = "HTTP_301"
        }
    }
}

resource aws_lb_target_group "example" {
    name = "example"
    target_type = "ip"  # FargeteはIP
    vpc_id = aws_vpc.example.id
    port = 80
    protocol = "HTTP" #HTTPSはELBで行っているため、HTTPにする。
    deregistration_delay = 300 # ALBが登録解除の待機時間

    health_check {
        path = "/"
        healthy_threshold = 5   # 正常判定の実行回数
        unhealthy_threshold = 2 # 異常判定の実行回数
        timeout = 5
        interval = 30
        matcher = 200   # 正常判定を行うために使用するHTTPステータスレコード
        port = "traffic-port" # traffic-port : portで指定したport
        protocol = "HTTP"
    }
    depends_on = [aws_lb.example] # ELBと同時作成するとエラーになる
}

# ターゲットグループにリクエストをフォワードするリスナールール
resource aws_lb_listener_rule "example" {
    listener_arn = aws_lb_listener.https.arn
    priority = 100 # 小さいほど優先度が高い
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.example.arn # foward先のグループ
    }
    # 条件
    condition {
        path_pattern {
            values = ["/*"] # 全てのパス
        }
    }
}