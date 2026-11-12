# Get Default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group: Expose ONLY the required port, NO SSH port 22 needed
resource "aws_security_group" "app_sg" {
  name        = "devops-task-sg-${var.environment}"
  description = "Allow inbound traffic for web service"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP on app port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devops-task-sg-${var.environment}"
    Environment = var.environment
  }
}

# IAM Role & Policies (Least Privilege)
resource "aws_iam_role" "ec2_role" {
  name = "devops-task-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM Core Policy (For GitHub Actions deployment & shell access)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Policy for CloudWatch Logs
resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  name = "devops-task-cw-logs-${var.environment}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.app_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devops-task-profile-${var.environment}"
  role = aws_iam_role.ec2_role.name
}

# CloudWatch Log Group with defined retention
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/devops-task/${var.environment}"
  retention_in_days = 7
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Pass variables into the user_data script
  user_data = templatefile("${path.module}/userdata.sh", {
    aws_region     = var.aws_region
    log_group_name = aws_cloudwatch_log_group.app_logs.name
    app_port       = var.app_port
  })

  tags = {
    Name        = "devops-task-server-${var.environment}"
    Environment = var.environment
  }
}