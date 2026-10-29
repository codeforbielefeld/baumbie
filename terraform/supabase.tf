# Self-hosted Supabase, ported from
# https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml
#
# When upgrading, bump local.supabase_ref together with the image tags below.

locals {
  hostname   = "${mittwald_project.baumbie.short_id}.project.space"
  public_url = "https://${local.hostname}"

  # Compose's .env: defaults from upstream's .env.example, secrets from var.supabase_env.
  env = merge({
    POSTGRES_HOST                = "db"
    POSTGRES_DB                  = "postgres"
    POSTGRES_PORT                = "5432"
    POOLER_TENANT_ID             = "baumbie"
    POOLER_DEFAULT_POOL_SIZE     = "20"
    POOLER_MAX_CLIENT_CONN       = "100"
    POOLER_DB_POOL_SIZE          = "5"
    STUDIO_DEFAULT_ORGANIZATION  = "Code for Bielefeld"
    STUDIO_DEFAULT_PROJECT       = "BaumBie"
    OPENAI_API_KEY               = ""
    SITE_URL                     = local.public_url
    ADDITIONAL_REDIRECT_URLS     = ""
    JWT_EXPIRY                   = "3600"
    DISABLE_SIGNUP               = "false"
    MAILER_URLPATHS_CONFIRMATION = "/auth/v1/verify"
    MAILER_URLPATHS_INVITE       = "/auth/v1/verify"
    MAILER_URLPATHS_RECOVERY     = "/auth/v1/verify"
    MAILER_URLPATHS_EMAIL_CHANGE = "/auth/v1/verify"
    ENABLE_EMAIL_SIGNUP          = "true"
    ENABLE_EMAIL_AUTOCONFIRM     = "false"
    SMTP_ADMIN_EMAIL             = "admin@example.com"
    SMTP_HOST                    = "supabase-mail"
    SMTP_PORT                    = "2500"
    SMTP_USER                    = "fake_mail_user"
    SMTP_PASS                    = "fake_mail_password"
    SMTP_SENDER_NAME             = "fake_sender"
    ENABLE_ANONYMOUS_USERS       = "false"
    ENABLE_PHONE_SIGNUP          = "true"
    ENABLE_PHONE_AUTOCONFIRM     = "true"
    GLOBAL_S3_BUCKET             = "stub"
    REGION                       = "stub"
    STORAGE_TENANT_ID            = "stub"
    FUNCTIONS_VERIFY_JWT         = "false"
    PGRST_DB_SCHEMAS             = "public,graphql_public"
    PGRST_DB_MAX_ROWS            = "1000"
    PGRST_DB_EXTRA_SEARCH_PATH   = "public"
    IMGPROXY_AUTO_WEBP           = "true"
    DASHBOARD_USERNAME           = "supabase"
    SUPABASE_PUBLISHABLE_KEY     = ""
    SUPABASE_SECRET_KEY          = ""
    ANON_KEY_ASYMMETRIC          = ""
    SERVICE_ROLE_KEY_ASYMMETRIC  = ""
    }, var.supabase_env, {
    SUPABASE_PUBLIC_URL = local.public_url
    API_EXTERNAL_URL    = "${local.public_url}/auth/v1"
  })
  postgres_url = "${local.env.POSTGRES_HOST}:${local.env.POSTGRES_PORT}/${local.env.POSTGRES_DB}"

  images = {
    studio    = "supabase/studio:2026.10.12-sha-3699278"
    api-gw    = "envoyproxy/envoy:v1.39.1"
    auth      = "supabase/gotrue:v2.197.0"
    rest      = "postgrest/postgrest:v14.18"
    realtime  = "supabase/realtime:v2.143.3"
    storage   = "supabase/storage-api:v1.81.0"
    imgproxy  = "darthsim/imgproxy:v3.31.4"
    meta      = "supabase/postgres-meta:v0.100.0"
    functions = "supabase/edge-runtime:v1.77.4"
    db        = "supabase/postgres:17.6.1.136"
    supavisor = "supabase/supavisor:2.9.13"
  }

  # Mittwald can't bind-mount local files (and caps entrypoint/command strings at
  # 800 chars), so the `config` container downloads the files compose mounts
  # from upstream's docker/volumes at this commit into shared volumes.
  supabase_ref = "2b3159381f36492f3d0e7793fa70b3972dba61e1"
  config_files = {
    "api/envoy/envoy.yaml"           = "/config/envoy/envoy.yaml"
    "api/envoy/cds.yaml"             = "/config/envoy/cds.yaml"
    "api/envoy/lds.template.yaml"    = "/config/envoy/lds.template.yaml"
    "api/envoy/docker-entrypoint.sh" = "/config/envoy/docker-entrypoint.sh"
    "db/realtime.sql"                = "/config/db/migrations/99-realtime.sql"
    "db/webhooks.sql"                = "/config/db/init-scripts/98-webhooks.sql"
    "db/roles.sql"                   = "/config/db/init-scripts/99-roles.sql"
    "db/jwt.sql"                     = "/config/db/init-scripts/99-jwt.sql"
    "db/_supabase.sql"               = "/config/db/migrations/97-_supabase.sql"
    "db/logs.sql"                    = "/config/db/migrations/99-logs.sql"
    "db/pooler.sql"                  = "/config/db/migrations/99-pooler.sql"
    "pooler/pooler.exs"              = "/config/pooler/pooler.exs"
    "functions/main/index.ts"        = "/functions/main/index.ts"
    "functions/deno.jsonc"           = "/functions/deno.jsonc"
  }

  # Containers using those files wait for the download, put them in place, then
  # exec their original command.
  config_entrypoint = {
    for name, setup in {
      api-gw = "cp /config/envoy/* /etc/envoy/"
      # Mittwald doesn't seed new volumes from the image, so only the pgsodium
      # key (generated on first start) lives in the db-config volume.
      db        = "cp -R /config/db/. /docker-entrypoint-initdb.d/ && chown postgres /db-config && ln -sf /db-config/pgsodium_root.key /etc/postgresql-custom/pgsodium_root.key"
      supavisor = ":"
      functions = ":"
    } : name => ["/bin/sh", "-c", "until [ -f /config/.done ]; do sleep 1; done; ${setup}; exec \"$@\"", "sh"]
  }
}

data "mittwald_container_image" "supabase" {
  for_each = local.images
  image    = each.value
}

moved {
  from = mittwald_container_stack.nginx
  to   = mittwald_container_stack.supabase
}

resource "mittwald_container_stack" "supabase" {
  project_id    = mittwald_project.baumbie.id
  default_stack = true

  containers = {
    studio = {
      description = "Supabase Studio"
      image       = local.images.studio
      entrypoint  = data.mittwald_container_image.supabase["studio"].entrypoint
      command     = data.mittwald_container_image.supabase["studio"].command
      ports       = [{ container_port = 3000, public_port = 3000, protocol = "tcp" }]
      environment = {
        HOSTNAME                         = "0.0.0.0"
        STUDIO_PG_META_URL               = "http://meta:8080"
        POSTGRES_PORT                    = local.env.POSTGRES_PORT
        POSTGRES_HOST                    = local.env.POSTGRES_HOST
        POSTGRES_DB                      = local.env.POSTGRES_DB
        POSTGRES_PASSWORD                = local.env.POSTGRES_PASSWORD
        POSTGRES_USER_READ_WRITE         = "postgres"
        PG_META_CRYPTO_KEY               = local.env.PG_META_CRYPTO_KEY
        PGRST_DB_SCHEMAS                 = local.env.PGRST_DB_SCHEMAS
        PGRST_DB_MAX_ROWS                = local.env.PGRST_DB_MAX_ROWS
        PGRST_DB_EXTRA_SEARCH_PATH       = local.env.PGRST_DB_EXTRA_SEARCH_PATH
        DEFAULT_ORGANIZATION_NAME        = local.env.STUDIO_DEFAULT_ORGANIZATION
        DEFAULT_PROJECT_NAME             = local.env.STUDIO_DEFAULT_PROJECT
        OPENAI_API_KEY                   = local.env.OPENAI_API_KEY
        SUPABASE_URL                     = "http://api-gw:8000"
        SUPABASE_PUBLIC_URL              = local.env.SUPABASE_PUBLIC_URL
        SUPABASE_ANON_KEY                = local.env.ANON_KEY
        SUPABASE_SERVICE_KEY             = local.env.SERVICE_ROLE_KEY
        AUTH_JWT_SECRET                  = local.env.JWT_SECRET
        SUPABASE_PUBLISHABLE_KEY         = local.env.SUPABASE_PUBLISHABLE_KEY
        SUPABASE_SECRET_KEY              = local.env.SUPABASE_SECRET_KEY
        ENABLED_FEATURES_LOGS_ALL        = "false"
        SNIPPETS_MANAGEMENT_FOLDER       = "/app/snippets"
        EDGE_FUNCTIONS_MANAGEMENT_FOLDER = "/app/edge-functions"
      }
      volumes = [
        { volume = "snippets", mount_path = "/app/snippets" },
        { volume = "functions", mount_path = "/app/edge-functions" },
      ]
    }

    api-gw = {
      description = "Supabase API gateway (Envoy)"
      image       = local.images.api-gw
      entrypoint  = local.config_entrypoint.api-gw
      command     = ["/bin/sh", "/etc/envoy/docker-entrypoint.sh"]
      environment = {
        ANON_KEY                    = local.env.ANON_KEY
        SERVICE_ROLE_KEY            = local.env.SERVICE_ROLE_KEY
        SUPABASE_PUBLISHABLE_KEY    = local.env.SUPABASE_PUBLISHABLE_KEY
        SUPABASE_SECRET_KEY         = local.env.SUPABASE_SECRET_KEY
        ANON_KEY_ASYMMETRIC         = local.env.ANON_KEY_ASYMMETRIC
        SERVICE_ROLE_KEY_ASYMMETRIC = local.env.SERVICE_ROLE_KEY_ASYMMETRIC
        SUPABASE_PUBLIC_URL         = local.env.SUPABASE_PUBLIC_URL
        DASHBOARD_USERNAME          = local.env.DASHBOARD_USERNAME
        DASHBOARD_PASSWORD          = local.env.DASHBOARD_PASSWORD
      }
      ports   = [{ container_port = 8000, public_port = 8000, protocol = "tcp" }]
      volumes = [{ volume = "config", mount_path = "/config" }]
    }

    auth = {
      description = "Supabase Auth (GoTrue)"
      image       = local.images.auth
      entrypoint  = data.mittwald_container_image.supabase["auth"].entrypoint
      command     = data.mittwald_container_image.supabase["auth"].command
      ports       = [{ container_port = 9999, public_port = 9999, protocol = "tcp" }]
      environment = {
        GOTRUE_API_HOST                         = "0.0.0.0"
        GOTRUE_API_PORT                         = "9999"
        API_EXTERNAL_URL                        = local.env.API_EXTERNAL_URL
        GOTRUE_DB_DRIVER                        = "postgres"
        GOTRUE_DB_DATABASE_URL                  = "postgres://supabase_auth_admin:${local.env.POSTGRES_PASSWORD}@${local.postgres_url}"
        GOTRUE_SITE_URL                         = local.env.SITE_URL
        GOTRUE_URI_ALLOW_LIST                   = local.env.ADDITIONAL_REDIRECT_URLS
        GOTRUE_DISABLE_SIGNUP                   = local.env.DISABLE_SIGNUP
        GOTRUE_JWT_ADMIN_ROLES                  = "service_role"
        GOTRUE_JWT_AUD                          = "authenticated"
        GOTRUE_JWT_DEFAULT_GROUP_NAME           = "authenticated"
        GOTRUE_JWT_EXP                          = local.env.JWT_EXPIRY
        GOTRUE_JWT_SECRET                       = local.env.JWT_SECRET
        GOTRUE_JWT_ISSUER                       = local.env.API_EXTERNAL_URL
        GOTRUE_EXTERNAL_EMAIL_ENABLED           = local.env.ENABLE_EMAIL_SIGNUP
        GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED = local.env.ENABLE_ANONYMOUS_USERS
        GOTRUE_MAILER_AUTOCONFIRM               = local.env.ENABLE_EMAIL_AUTOCONFIRM
        GOTRUE_SMTP_ADMIN_EMAIL                 = local.env.SMTP_ADMIN_EMAIL
        GOTRUE_SMTP_HOST                        = local.env.SMTP_HOST
        GOTRUE_SMTP_PORT                        = local.env.SMTP_PORT
        GOTRUE_SMTP_USER                        = local.env.SMTP_USER
        GOTRUE_SMTP_PASS                        = local.env.SMTP_PASS
        GOTRUE_SMTP_SENDER_NAME                 = local.env.SMTP_SENDER_NAME
        GOTRUE_MAILER_URLPATHS_INVITE           = local.env.MAILER_URLPATHS_INVITE
        GOTRUE_MAILER_URLPATHS_CONFIRMATION     = local.env.MAILER_URLPATHS_CONFIRMATION
        GOTRUE_MAILER_URLPATHS_RECOVERY         = local.env.MAILER_URLPATHS_RECOVERY
        GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE     = local.env.MAILER_URLPATHS_EMAIL_CHANGE
        GOTRUE_EXTERNAL_PHONE_ENABLED           = local.env.ENABLE_PHONE_SIGNUP
        GOTRUE_SMS_AUTOCONFIRM                  = local.env.ENABLE_PHONE_AUTOCONFIRM
      }
    }

    rest = {
      description = "Supabase REST (PostgREST)"
      image       = local.images.rest
      entrypoint  = data.mittwald_container_image.supabase["rest"].entrypoint
      command     = ["postgrest"]
      ports       = [{ container_port = 3000, public_port = 3000, protocol = "tcp" }]
      environment = {
        PGRST_DB_URI               = "postgres://authenticator:${local.env.POSTGRES_PASSWORD}@${local.postgres_url}"
        PGRST_DB_SCHEMAS           = local.env.PGRST_DB_SCHEMAS
        PGRST_DB_MAX_ROWS          = local.env.PGRST_DB_MAX_ROWS
        PGRST_DB_EXTRA_SEARCH_PATH = local.env.PGRST_DB_EXTRA_SEARCH_PATH
        PGRST_DB_ANON_ROLE         = "anon"
        PGRST_ADMIN_SERVER_PORT    = "3001"
        PGRST_ADMIN_SERVER_HOST    = "localhost"
        PGRST_JWT_SECRET           = local.env.JWT_SECRET
        PGRST_DB_USE_LEGACY_GUCS   = "false"
        PGRST_APP_SETTINGS_JWT_EXP = local.env.JWT_EXPIRY
      }
    }

    realtime = {
      description = "Supabase Realtime"
      image       = local.images.realtime
      entrypoint  = data.mittwald_container_image.supabase["realtime"].entrypoint
      command     = data.mittwald_container_image.supabase["realtime"].command
      ports       = [{ container_port = 4000, public_port = 4000, protocol = "tcp" }]
      environment = {
        PORT                        = "4000"
        DB_HOST                     = local.env.POSTGRES_HOST
        DB_PORT                     = local.env.POSTGRES_PORT
        DB_USER                     = "supabase_admin"
        DB_PASSWORD                 = local.env.POSTGRES_PASSWORD
        DB_NAME                     = local.env.POSTGRES_DB
        DB_AFTER_CONNECT_QUERY      = "SET search_path TO _realtime"
        DB_ENC_KEY                  = local.env.REALTIME_DB_ENC_KEY
        API_JWT_SECRET              = local.env.JWT_SECRET
        SECRET_KEY_BASE             = local.env.SECRET_KEY_BASE
        METRICS_JWT_SECRET          = local.env.JWT_SECRET
        ERL_AFLAGS                  = "-proto_dist inet_tcp"
        DNS_NODES                   = "''"
        RLIMIT_NOFILE               = "10000"
        APP_NAME                    = "realtime"
        SEED_SELF_HOST              = "true"
        RUN_JANITOR                 = "true"
        DISABLE_HEALTHCHECK_LOGGING = "true"
      }
    }

    storage = {
      description = "Supabase Storage"
      image       = local.images.storage
      entrypoint  = data.mittwald_container_image.supabase["storage"].entrypoint
      command     = data.mittwald_container_image.supabase["storage"].command
      ports       = [{ container_port = 5000, public_port = 5000, protocol = "tcp" }]
      environment = {
        ANON_KEY                       = local.env.ANON_KEY
        SERVICE_KEY                    = local.env.SERVICE_ROLE_KEY
        POSTGREST_URL                  = "http://rest:3000"
        AUTH_JWT_SECRET                = local.env.JWT_SECRET
        DATABASE_URL                   = "postgres://supabase_storage_admin:${local.env.POSTGRES_PASSWORD}@${local.postgres_url}"
        STORAGE_PUBLIC_URL             = local.env.SUPABASE_PUBLIC_URL
        REQUEST_ALLOW_X_FORWARDED_PATH = "true"
        FILE_SIZE_LIMIT                = "52428800"
        STORAGE_BACKEND                = "file"
        GLOBAL_S3_BUCKET               = local.env.GLOBAL_S3_BUCKET
        FILE_STORAGE_BACKEND_PATH      = "/var/lib/storage"
        TENANT_ID                      = local.env.STORAGE_TENANT_ID
        REGION                         = local.env.REGION
        ENABLE_IMAGE_TRANSFORMATION    = "true"
        IMGPROXY_URL                   = "http://imgproxy:5001"
        S3_PROTOCOL_ACCESS_KEY_ID      = local.env.S3_PROTOCOL_ACCESS_KEY_ID
        S3_PROTOCOL_ACCESS_KEY_SECRET  = local.env.S3_PROTOCOL_ACCESS_KEY_SECRET
      }
      volumes = [{ volume = "storage", mount_path = "/var/lib/storage" }]
    }

    imgproxy = {
      description = "Supabase image transformation (imgproxy)"
      image       = local.images.imgproxy
      entrypoint  = data.mittwald_container_image.supabase["imgproxy"].entrypoint
      command     = data.mittwald_container_image.supabase["imgproxy"].command
      ports       = [{ container_port = 5001, public_port = 5001, protocol = "tcp" }]
      environment = {
        IMGPROXY_BIND                  = ":5001"
        IMGPROXY_LOCAL_FILESYSTEM_ROOT = "/"
        IMGPROXY_USE_ETAG              = "true"
        IMGPROXY_AUTO_WEBP             = local.env.IMGPROXY_AUTO_WEBP
        IMGPROXY_MAX_SRC_RESOLUTION    = "16.8"
      }
      volumes = [{ volume = "storage", mount_path = "/var/lib/storage" }]
    }

    meta = {
      description = "Supabase postgres-meta"
      image       = local.images.meta
      entrypoint  = data.mittwald_container_image.supabase["meta"].entrypoint
      command     = data.mittwald_container_image.supabase["meta"].command
      ports       = [{ container_port = 8080, public_port = 8080, protocol = "tcp" }]
      environment = {
        PG_META_PORT        = "8080"
        PG_META_DB_HOST     = local.env.POSTGRES_HOST
        PG_META_DB_PORT     = local.env.POSTGRES_PORT
        PG_META_DB_NAME     = local.env.POSTGRES_DB
        PG_META_DB_USER     = "postgres"
        PG_META_DB_PASSWORD = local.env.POSTGRES_PASSWORD
        CRYPTO_KEY          = local.env.PG_META_CRYPTO_KEY
      }
    }

    functions = {
      description = "Supabase Edge Functions"
      image       = local.images.functions
      entrypoint  = local.config_entrypoint.functions
      command = concat(data.mittwald_container_image.supabase["functions"].entrypoint, [
        "start", "--user-worker-request-idle-timeout", "150000", "--main-service", "/home/deno/functions/main",
      ])
      ports = [{ container_port = 9000, public_port = 9000, protocol = "tcp" }]
      environment = {
        JWT_SECRET                = local.env.JWT_SECRET
        SUPABASE_URL              = "http://api-gw:8000"
        SUPABASE_PUBLIC_URL       = local.env.SUPABASE_PUBLIC_URL
        SUPABASE_ANON_KEY         = local.env.ANON_KEY
        SUPABASE_SERVICE_ROLE_KEY = local.env.SERVICE_ROLE_KEY
        SUPABASE_PUBLISHABLE_KEYS = jsonencode({ default = local.env.SUPABASE_PUBLISHABLE_KEY })
        SUPABASE_SECRET_KEYS      = jsonencode({ default = local.env.SUPABASE_SECRET_KEY })
        SUPABASE_DB_URL           = "postgresql://postgres:${local.env.POSTGRES_PASSWORD}@${local.postgres_url}"
        VERIFY_JWT                = local.env.FUNCTIONS_VERIFY_JWT
      }
      volumes = [
        { volume = "functions", mount_path = "/home/deno/functions" },
        { volume = "deno-cache", mount_path = "/root/.cache/deno" },
        { volume = "config", mount_path = "/config" },
      ]
    }

    db = {
      description = "Supabase Postgres"
      image       = local.images.db
      entrypoint  = local.config_entrypoint.db
      command = concat(data.mittwald_container_image.supabase["db"].entrypoint, [
        "postgres", "-c", "config_file=/etc/postgresql/postgresql.conf", "-c", "log_min_messages=fatal",
      ])
      ports = [{ container_port = 5432, public_port = 5432, protocol = "tcp" }]
      environment = {
        POSTGRES_HOST     = "/var/run/postgresql"
        PGPORT            = local.env.POSTGRES_PORT
        POSTGRES_PORT     = local.env.POSTGRES_PORT
        PGPASSWORD        = local.env.POSTGRES_PASSWORD
        POSTGRES_PASSWORD = local.env.POSTGRES_PASSWORD
        PGDATABASE        = local.env.POSTGRES_DB
        POSTGRES_DB       = local.env.POSTGRES_DB
        JWT_EXP           = local.env.JWT_EXPIRY
      }
      volumes = [
        { volume = "postgres-data", mount_path = "/var/lib/postgresql/data" },
        { volume = "db-config", mount_path = "/db-config" },
        { volume = "config", mount_path = "/config" },
      ]
    }

    supavisor = {
      description = "Supabase connection pooler (Supavisor)"
      image       = local.images.supavisor
      entrypoint  = local.config_entrypoint.supavisor
      command = concat(data.mittwald_container_image.supabase["supavisor"].entrypoint, [
        "/bin/sh", "-c", "/app/bin/migrate && /app/bin/supavisor eval \"$(cat /config/pooler/pooler.exs)\" && /app/bin/server",
      ])
      volumes = [{ volume = "config", mount_path = "/config" }]
      environment = {
        PORT                     = "4000"
        POSTGRES_PORT            = local.env.POSTGRES_PORT
        POSTGRES_HOST            = local.env.POSTGRES_HOST
        POSTGRES_DB              = local.env.POSTGRES_DB
        POSTGRES_PASSWORD        = local.env.POSTGRES_PASSWORD
        DATABASE_URL             = "ecto://supabase_admin:${local.env.POSTGRES_PASSWORD}@${local.env.POSTGRES_HOST}:${local.env.POSTGRES_PORT}/_supabase"
        CLUSTER_POSTGRES         = "true"
        SECRET_KEY_BASE          = local.env.SECRET_KEY_BASE
        VAULT_ENC_KEY            = local.env.VAULT_ENC_KEY
        API_JWT_SECRET           = local.env.JWT_SECRET
        METRICS_JWT_SECRET       = local.env.JWT_SECRET
        REGION                   = "local"
        ERL_AFLAGS               = "-proto_dist inet_tcp"
        POOLER_TENANT_ID         = local.env.POOLER_TENANT_ID
        POOLER_DEFAULT_POOL_SIZE = local.env.POOLER_DEFAULT_POOL_SIZE
        POOLER_MAX_CLIENT_CONN   = local.env.POOLER_MAX_CLIENT_CONN
        POOLER_POOL_MODE         = "transaction"
        DB_POOL_SIZE             = local.env.POOLER_DB_POOL_SIZE
      }
    }

    config = {
      description = "Downloads Supabase config files into shared volumes"
      image       = "alpine:3.20.3"
      entrypoint = ["/bin/sh", "-c", <<-EOT
        set -e
        rm -f /config/.done
        for p in "$@"; do
          d="$${p#*=}"
          mkdir -p "$(dirname "$d")"
          wget -qO "$d" "https://raw.githubusercontent.com/supabase/supabase/${local.supabase_ref}/docker/volumes/$${p%%=*}"
        done
        # Container hostnames can't contain dots; envoy already rewrites the Host header to the tenant realtime expects.
        sed -i s/realtime-dev.supabase-realtime/realtime/ /config/envoy/cds.yaml
        touch /config/.done
        exec tail -f /dev/null
      EOT
      , "sh"]
      command = [for src, dest in local.config_files : "${src}=${dest}"]
      volumes = [
        { volume = "config", mount_path = "/config" },
        { volume = "functions", mount_path = "/functions" },
      ]
    }
  }

  volumes = {
    config        = {}
    postgres-data = {}
    db-config     = {}
    storage       = {}
    functions     = {}
    snippets      = {}
    deno-cache    = {}
  }

  update_schedule = {
    cron     = "0 3 * * *"
    timezone = "Europe/Berlin"
  }

  timeouts {
    create = "30m"
    update = "30m"
  }
}

moved {
  from = mittwald_virtualhost.nginx
  to   = mittwald_virtualhost.supabase
}

resource "mittwald_virtualhost" "supabase" {
  hostname   = local.hostname
  project_id = mittwald_project.baumbie.id

  paths = {
    "/" = {
      container = {
        container_id = mittwald_container_stack.supabase.containers.api-gw.id
        port         = "8000/tcp"
      }
    }
  }
}
