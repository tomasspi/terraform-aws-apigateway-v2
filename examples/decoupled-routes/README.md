# Decoupled Routes Example

This example demonstrates how to decouple API Gateway management from route management, allowing:

- **Infrastructure teams** to manage the API Gateway, authorizers, and stage centrally
- **Service teams** to manage their own routes and integrations independently

## Architecture

```
  ┌───────────────────────────────────────────────────┐
  │                Infrastructure Team                │
  │  ┌──────────────────────────────────────────────┐ │
  │  │              API Gateway Module              │ │
  │  │  API Gateway                                 │ │
  │  │  Authorizers (JWT, etc.)                     │ │
  │  │  Stage & Logging                             │ │
  │  │  CORS Configuration                          │ │
  │  └──────────────────────────────────────────────┘ │
  └───────────────────────────────────────────────────┘
                             │
                             │ api_id
                             ▼
┌──────────────────────────────────────────────────────────┐
│                     Service Teams                        │
│  ┌──────────────────────┐    ┌────────────────────────┐  │
│  │   Service A Routes   │    │      Service B Routes  │  │
│  │  GET /service-a/*    │    │   GET /service-b/*     │  │
│  │  POST /service-a/*   │    │   POST /service-b/*    │  │
│  │  Lambda Integration  │    │   Lambda Integration   │  │
│  └──────────────────────┘    └────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Key Features

### 1. **Centralized API Gateway Management**
- Single API Gateway managed by infrastructure team
- Centralized authorizers (JWT, Cognito, etc.)
- Unified CORS and stage configuration
- Centralized logging and monitoring

### 2. **Decoupled Route Management**
- Each service manages its own routes
- Independent deployment cycles
- Service-specific Lambda integrations
- Isolated route configurations

### 3. **Shared Resources**
- Routes reference centralized authorizers
- All routes use the same API Gateway endpoint
- Shared stage and logging configuration

## Usage

### Infrastructure Team (API Gateway)
```hcl
module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name         = "central-api"
  description  = "Centralized API Gateway"
  
  # Don't create routes - managed separately
  create_routes_and_integrations = false

  # Centralized authorizers
  authorizers = {
    jwt_auth = {
      authorizer_type  = "JWT"
      identity_sources = ["$request.header.Authorization"]
      jwt_configuration = {
        audience = ["example-audience"]
        issuer   = "https://cognito-idp.region.amazonaws.com/pool_id"
      }
    }
  }
}
```

### Service Team A (Routes)
```hcl
module "service_a_routes" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  # Use external API Gateway
  external_api_id = var.api_gateway_id
  
  # Don't create API Gateway
  create = false
  create_routes_and_integrations = true

  routes = {
    "GET /service-a/health" = {
      integration = {
        uri = module.lambda_service_a.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
    
    "POST /service-a/users" = {
      authorization_type = "JWT"
      authorizer_key     = "jwt_auth"  # Reference centralized authorizer
      
      integration = {
        uri = module.lambda_service_a.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
  }
}
```

## Benefits

1. **🏗️ Separation of Concerns**: Infrastructure and application teams can work independently
2. **🔒 Centralized Security**: Authorizers managed in one place
3. **📈 Scalability**: Each service can manage routes independently
4. **🚀 Independent Deployments**: Services can deploy routes without affecting others
5. **🔄 Backward Compatibility**: Existing single-module usage still works

## Running This Example

```bash
terraform init
terraform plan
terraform apply
```

## Testing

After deployment, you can test the endpoints:

```bash
# Get the API endpoint
API_ENDPOINT=$(terraform output -raw stage_invoke_url)

# Test Service A health endpoint
curl $API_ENDPOINT/service-a/health

# Test Service B health endpoint  
curl $API_ENDPOINT/service-b/health

# Test authenticated endpoints (requires JWT token)
curl -H "Authorization: Bearer <jwt-token>" $API_ENDPOINT/service-a/users
```

## Cleanup

```bash
terraform destroy
```
