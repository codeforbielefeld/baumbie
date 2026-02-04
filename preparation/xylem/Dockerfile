FROM elixir:1.18.4-otp-27-slim

# CA-Zertifikate für HTTPS-Downloads installieren
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Fix this issue on Apple Silicon: https://elixirforum.com/t/unable-to-compile-default-elixir-project-from-the-getting-started-guide/57199/12
ENV ERL_FLAGS="+JPperf true"

ENV MIX_ENV=prod

# Hex und rebar installieren
RUN mix local.hex --force && \
    mix local.rebar --force

# Dependencies zuerst kopieren (für besseres Caching)
COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile

# Restlichen Code kopieren
COPY config config
COPY lib lib

RUN mix compile

VOLUME ["/app/data", "/app/priv"]

ENTRYPOINT ["mix", "xylem.generate"]