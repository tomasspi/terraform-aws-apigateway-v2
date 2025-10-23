provider "aws" {
  region = local.region
}

locals {
  name   = "ex-${basename(path.cwd)}"
  region = "eu-west-1"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-apigateway-v2"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# Centralized API Gateway (Infrastructure Team)
################################################################################

module "api_gateway" {
  source = "../../"

  # API Gateway configuration
  name         = "${local.name}-central"
  description  = "Centralized API Gateway managed by infrastructure team"
  protocol_type = "HTTP"

  # Disable route creation - routes will be managed separately
  create_routes_and_integrations = false

  # Centralized authorizers
  authorizers = {
    jwt_auth = {
      authorizer_type  = "JWT"
      identity_sources = ["$request.header.Authorization"]
      name             = "jwt-authorizer"
      jwt_configuration = {
        audience = ["example-audience"]
        issuer   = "https://${aws_cognito_user_pool.this.endpoint}"
      }
    }
  }

  # CORS configuration
  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  # Stage configuration
  stage_access_log_settings = {
    create_log_group            = true
    log_group_retention_in_days = 7
  }

  stage_default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 100
  }

  tags = local.tags
}

################################################################################
# Service A Routes (Service Team A)
################################################################################

module "service_a_routes" {
  source = "../../"

  # Use external API Gateway
  external_api_id = module.api_gateway.api_id
  
  # Don't create API Gateway resources
  create                = false
  create_routes_and_integrations = true

  # Service A specific routes
  routes = {
    "GET /service-a/health" = {
      integration = {
        uri                    = module.lambda_service_a.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
      }
    }

    "POST /service-a/users" = {
      authorization_type = "JWT"
      authorizer_key     = "jwt_auth"  # Reference to centralized authorizer
      
      integration = {
        uri                    = module.lambda_service_a.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
      }
    }

    "GET /service-a/users/{id}" = {
      authorization_type = "JWT"
      authorizer_key     = "jwt_auth"
      
      integration = {
        uri                    = module.lambda_service_a.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
      }
    }
  }

  tags = merge(local.tags, {
    Service = "service-a"
  })
}

################################################################################
# Service B Routes (Service Team B)
################################################################################

module "service_b_routes" {
  source = "../../"

  # Use external API Gateway
  external_api_id = module.api_gateway.api_id
  
  # Don't create API Gateway resources
  create                = false
  create_routes_and_integrations = true

  # Service B specific routes
  routes = {
    "GET /service-b/health" = {
      integration = {
        uri                    = module.lambda_service_b.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
      }
    }

    "GET /service-b/orders" = {
      authorization_type = "JWT"
      authorizer_key     = "jwt_auth"  # Reference to centralized authorizer
      
      integration = {
        uri                    = module.lambda_service_b.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
      }
    }

    "POST /service-b/orders" = {
      authorization_type = "JWT"
      authorizer_key     = "jwt_auth"
      
      integration = {
        uri                    = module.lambda_service_b.lambda_function_arn
        payload_format_version = "2.0"
        type                   = "AWS_PROXY"
        timeout_milliseconds   = 15000
      }
    }
  }

  tags = merge(local.tags, {
    Service = "service-b"
  })
}

################################################################################
# Supporting Resources
################################################################################

# Cognito User Pool for JWT authentication
resource "aws_cognito_user_pool" "this" {
  name = local.name
  tags = local.tags
}

# Lambda function for Service A
module "lambda_service_a" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name}-service-a"
  description   = "Service A Lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]

  create_package         = false
  local_existing_package = local.downloaded_package

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }

  tags = merge(local.tags, {
    Service = "service-a"
  })
}

# Lambda function for Service B
module "lambda_service_b" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${local.name}-service-b"
  description   = "Service B Lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]

  create_package         = false
  local_existing_package = local.downloaded_package

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }

  tags = merge(local.tags, {
    Service = "service-b"
  })
}

# Download Lambda package
locals {
  package_url = "https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-lambda/master/examples/fixtures/python-function.zip"
  downloaded_package  = "downloaded_package_${md5(local.package_url)}.zip"
}

resource "null_resource" "download_package" {
  triggers = {
    downloaded = local.downloaded_package
  }

  provisioner "local-exec" {
    command = "curl -L -o ${local.downloaded_package} ${local.package_url}"
  }
}
