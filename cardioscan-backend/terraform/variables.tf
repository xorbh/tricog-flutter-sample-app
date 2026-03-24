variable "neon_api_key" {
  description = "Neon API key"
  type        = string
  sensitive   = true
}

variable "neon_region" {
  description = "Neon project region"
  type        = string
  default     = "aws-us-east-1"
}
