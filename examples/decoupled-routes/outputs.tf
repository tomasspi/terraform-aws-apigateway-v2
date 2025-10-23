################################################################################
# API Gateway
################################################################################

output "api_id" {
  description = "The API identifier"
  value       = module.api_gateway.api_id
}

output "api_endpoint" {
  description = "URI of the API"
  value       = module.api_gateway.api_endpoint
}

output "api_arn" {
  description = "The ARN of the API"
  value       = module.api_gateway.api_arn
}

output "stage_invoke_url" {
  description = "The URL to invoke the API pointing to the stage"
  value       = module.api_gateway.stage_invoke_url
}

################################################################################
# Authorizers
################################################################################

output "authorizers" {
  description = "Map of API Gateway Authorizer(s) created and their attributes"
  value       = module.api_gateway.authorizers
}

################################################################################
# Service Routes
################################################################################

output "service_a_routes" {
  description = "Service A routes created"
  value       = module.service_a_routes.routes
}

output "service_b_routes" {
  description = "Service B routes created"
  value       = module.service_b_routes.routes
}

output "service_a_integrations" {
  description = "Service A integrations created"
  value       = module.service_a_routes.integrations
}

output "service_b_integrations" {
  description = "Service B integrations created"
  value       = module.service_b_routes.integrations
}
