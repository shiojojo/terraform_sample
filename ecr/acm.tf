
# ACMの設定
resource aws_acm_certificate "example" {
    domain_name = data.aws_route53_zone.example.name  # ドメイン名
    subject_alternative_names = []  # ドメイン名を追加する場合は追加
    validation_method = "DNS"       # ドメインの所有権の検証方法、SSL証明書を自動更新はDNS
    # Terraform独自機能、前リソースで設定可能
    lifecycle {
        create_before_destroy = true # リソースを作成してから削除する。
    }
}

# ACMのレコード登録
resource aws_route53_record "example_certificate" {
    # AWS Provider 3.0.0 以降からlist型からset型へ変更
    for_each = {
        # ACMの値を取得
        for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }
    name = each.value.name  # ACMのレコード名
    type = each.value.type  # ACMのタイプ　：　CNAME
    records = [each.value.record]  # ACMの 値/トラフィックのルーティング先
    zone_id = data.aws_route53_zone.example.id
    ttl = 60
}

# ACM証明書とCNAMEレコードの連携
resource aws_acm_certificate_validation "example" {
    certificate_arn = aws_acm_certificate.example.arn
    validation_record_fqdns = [for record in aws_route53_record.example_certificate : record.fqdn]
}

