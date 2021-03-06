# VPC作成
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  # DNS有効化
  enable_dns_support = true
  # パブリックDNSの自動割り当て
  enable_dns_hostnames = true
  tags = {
    Name = "example"
  }
}

# サブネット
resource "aws_subnet" "public_0" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
  # パブリックIPの自動割り当て
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
}
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.2.0/24"
  # パブリックIPの自動割り当て
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

# ルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

# ルートテーブルのルート
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

# ルートテーブルのサブネット割り当て
resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# private
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"
}
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

# プライベート割り当て
resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

# EIP
resource "aws_eip" "nat_gateway_0" {
  vpc = true
  # 依存関係_インターネットゲートウェイの後に作成
  depends_on = [aws_internet_gateway.example]
}
resource "aws_eip" "nat_gateway_1" {
  vpc = true
  # 依存関係_インターネットゲートウェイの後に作成
  depends_on = [aws_internet_gateway.example]
}

# NATゲートウェイ
resource "aws_nat_gateway" "nat_gateway_0" {
  # EIPを設定
  allocation_id = aws_eip.nat_gateway_0.id
  # NATゲートウェイ置くサブネットを指定
  subnet_id = aws_subnet.public_0.id
  # 依存関係_インターネットゲートウェイの後に作成
  depends_on = [aws_internet_gateway.example]
}
resource "aws_nat_gateway" "nat_gateway_1" {
  # EIPを設定
  allocation_id = aws_eip.nat_gateway_1.id
  # NATゲートウェイ置くサブネットを指定
  subnet_id = aws_subnet.public_1.id
  # 依存関係_インターネットゲートウェイの後に作成
  depends_on = [aws_internet_gateway.example]
}

# プライベートのルートテーブルのNATゲートウェイを追加
resource aws_route "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}
resource aws_route "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

