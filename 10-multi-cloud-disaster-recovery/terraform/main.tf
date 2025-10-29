terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Region Provider
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# Secondary Region Provider
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  provider = aws.primary
  name     = var.domain_name
  
  tags = local.common_tags
}

# Primary Region Infrastructure
module "primary_region" {
  source = "./modules/region"
  
  providers = {
    aws = aws.primary
  }
  
  region                = var.primary_region
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.primary_vpc_cidr
  public_subnet_cidrs  = var.primary_public_subnets
  private_subnet_cidrs = var.primary_private_subnets
  
  # Database configuration
  db_instance_class    = var.db_instance_class
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  backup_retention    = 7
  
  # Enable cross-region backup
  enable_cross_region_backup = true
  backup_destination_region  = var.secondary_region
  
  tags = local.common_tags
}

# Secondary Region Infrastructure
module "secondary_region" {
  source = "./modules/region"
  
  providers = {
    aws = aws.secondary
  }
  
  region                = var.secondary_region
  project_name         = var.project_name
  environment          = "${var.environment}-dr"
  vpc_cidr             = var.secondary_vpc_cidr
  public_subnet_cidrs  = var.secondary_public_subnets
  private_subnet_cidrs = var.secondary_private_subnets
  
  # Database configuration (read replica)
  db_instance_class    = var.db_instance_class
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  
  # This will be a read replica
  is_read_replica           = true
  source_db_identifier      = module.primary_region.db_identifier
  source_db_region         = var.primary_region
  
  tags = local.common_tags
}

# Cross-Region RDS Read Replica
resource "aws_db_instance" "read_replica" {
  provider = aws.secondary
  
  identifier = "${var.project_name}-${var.environment}-replica"
  
  # Read replica configuration
  replicate_source_db = module.primary_region.db_identifier
  
  instance_class = var.db_instance_class
  
  # Read replica specific settings
  auto_minor_version_upgrade = true
  backup_retention_period    = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  
  # Security
  vpc_security_group_ids = [module.secondary_region.db_security_group_id]
  db_subnet_group_name   = module.secondary_region.db_subnet_group_name
  
  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  # Performance Insights
  performance_insights_enabled = true
  
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-replica-final-snapshot"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-replica"
    Type = "ReadReplica"
  })
}

# RDS Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  provider = aws.secondary
  name     = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  provider   = aws.secondary
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# S3 Cross-Region Replication
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.project_name}-primary-${random_string.suffix.result}"
  
  tags = local.common_tags
}

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "${var.project_name}-secondary-${random_string.suffix.result}"
  
  tags = local.common_tags
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket Versioning (required for replication)
resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Replication Configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary]
  
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-everything"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# IAM Role for S3 Replication
resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-s3-replication-policy"
  role     = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}

# Route 53 Health Checks and Failover
resource "aws_route53_health_check" "primary" {
  provider                        = aws.primary
  fqdn                           = module.primary_region.alb_dns_name
  port                           = 80
  type                           = "HTTP"
  resource_path                  = "/health"
  failure_threshold              = 3
  request_interval               = 30
  cloudwatch_alarm_region        = var.primary_region
  cloudwatch_alarm_name          = "${var.project_name}-primary-health"
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-primary-health-check"
  })
}

# Route 53 Records with Failover
resource "aws_route53_record" "primary" {
  provider = aws.primary
  zone_id  = aws_route53_zone.main.zone_id
  name     = var.domain_name
  type     = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = module.primary_region.alb_dns_name
    zone_id                = module.primary_region.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  provider = aws.primary
  zone_id  = aws_route53_zone.main.zone_id
  name     = var.domain_name
  type     = "A"

  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.secondary_region.alb_dns_name
    zone_id                = module.secondary_region.alb_zone_id
    evaluate_target_health = true
  }
}

# CloudWatch Alarms for Disaster Recovery
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  provider            = aws.primary
  alarm_name          = "${var.project_name}-primary-region-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors primary region health"
  alarm_actions       = [aws_sns_topic.dr_notifications.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }
}

# SNS Topic for DR Notifications
resource "aws_sns_topic" "dr_notifications" {
  provider = aws.primary
  name     = "${var.project_name}-dr-notifications"
  
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.dr_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Lambda function for automated failover
resource "aws_lambda_function" "failover_automation" {
  provider      = aws.primary
  filename      = "failover_automation.zip"
  function_name = "${var.project_name}-failover-automation"
  role          = aws_iam_role.lambda_failover.arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 300

  environment {
    variables = {
      PRIMARY_REGION   = var.primary_region
      SECONDARY_REGION = var.secondary_region
      DB_IDENTIFIER    = module.primary_region.db_identifier
      REPLICA_ID       = aws_db_instance.read_replica.id
    }
  }

  tags = local.common_tags
}

# IAM Role for Lambda Failover Function
resource "aws_iam_role" "lambda_failover" {
  provider = aws.primary
  name     = "${var.project_name}-lambda-failover-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_failover" {
  provider = aws.primary
  name     = "${var.project_name}-lambda-failover-policy"
  role     = aws_iam_role.lambda_failover.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.dr_notifications.arn
      }
    ]
  })
}