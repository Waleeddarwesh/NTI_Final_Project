###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support    = var.enable_dns_support

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

###############################################################################
# Public Subnets
###############################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.extra_tags,
    {
      Name                                          = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Tier                                          = "public"
      "kubernetes.io/role/elb"                      = "1"
      "kubernetes.io/cluster/${var.project_name}-${var.environment}-eks" = "shared"
    }
  )
}

###############################################################################
# Private Subnets
###############################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.extra_tags,
    {
      Name                                          = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
      Tier                                          = "private"
      "kubernetes.io/role/internal-elb"             = "1"
      "kubernetes.io/cluster/${var.project_name}-${var.environment}-eks" = "shared"
    }
  )
}

###############################################################################
# Elastic IPs for NAT Gateway(s)
#
# single_nat_gateway = true  -> 1 EIP, 1 NAT GW, shared by all private subnets
# single_nat_gateway = false -> 1 EIP + 1 NAT GW per AZ, full HA, higher cost
###############################################################################

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

###############################################################################
# NAT Gateway(s)
###############################################################################

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

###############################################################################
# Public Route Table (single, shared by all public subnets)
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Private Route Table(s)
#
# single_nat_gateway = true  -> 1 shared private route table, all private
#                                subnets route through the single NAT GW
# single_nat_gateway = false -> 1 private route table per AZ, each routing
#                                through its own AZ-local NAT GW
###############################################################################

resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    # Explicit, not relied-on-coincidence: when single_nat_gateway is true,
    # this resource only ever has count.index == 0, so we pin to NAT GW 0
    # regardless of count.index; when false, indices line up 1:1 with AZs.
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt-${count.index}"
    }
  )
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
