variable "mittwald_api_key" {
  type      = string
  sensitive = true
}

variable "customer_id" {
  type      = string
  sensitive = true
}

variable "server_id" {
  type = string
}
# Supabase .env values (see https://github.com/supabase/supabase/blob/master/docker/.env.example);
# overrides the defaults in supabase.tf. Secrets live in mittwald.tfvars.
variable "supabase_env" {
  type      = map(string)
  sensitive = true

  validation {
    condition = alltrue([for k in [
      "POSTGRES_PASSWORD", "JWT_SECRET", "ANON_KEY", "SERVICE_ROLE_KEY", "DASHBOARD_PASSWORD",
      "SECRET_KEY_BASE", "REALTIME_DB_ENC_KEY", "VAULT_ENC_KEY", "PG_META_CRYPTO_KEY",
      "S3_PROTOCOL_ACCESS_KEY_ID", "S3_PROTOCOL_ACCESS_KEY_SECRET",
    ] : length(lookup(var.supabase_env, k, "")) > 0])
    error_message = "supabase_env is missing secrets; set them in the supabase_env block in mittwald.tfvars. To generate new ones, run Supabase's docker/utils/generate-keys.sh (https://github.com/supabase/supabase/blob/master/docker/utils/generate-keys.sh)."
  }
}
