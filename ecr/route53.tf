data aws_route53_zone "example" {
    name = "shiojojo.net"
}

# resource aws_route53_zone "test_example" {
#     name = "test.shiojojo.com"
# }

resource aws_route53_record "example" {
    zone_id = data.aws_route53_zone.example.zone_id
    name = data.aws_route53_zone.example.name # ドメイン名指定
    type = "A"  # ALIASレコード（AWS独自拡張のAレコード）AWSのサービスも指定できる。
    alias {
        name = aws_lb.example.dns_name
        zone_id = aws_lb.example.zone_id
        # エイリアスレコードが参照するリソース(ELB等の)の正常性ステータスをチェック
        evaluate_target_health = true 
    }
}

output "domain_name" {
    value = aws_route53_record.example.name
}

