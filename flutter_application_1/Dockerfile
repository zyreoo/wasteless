FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 --branch 3.47.2 \
      https://github.com/flutter/flutter.git /opt/flutter \
    && useradd --create-home --shell /bin/bash flutter \
    && chown -R flutter:flutter /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
USER flutter
RUN flutter config --enable-web && flutter precache --web
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY
ARG API_BASE_URL
ARG AUTH_REDIRECT_URL
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN test -n "$SUPABASE_URL" && test -n "$SUPABASE_PUBLISHABLE_KEY" \
    && test -n "$API_BASE_URL" && test -n "$AUTH_REDIRECT_URL"
RUN flutter build web --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=AUTH_REDIRECT_URL="$AUTH_REDIRECT_URL"

FROM nginx:1.27-alpine
ENV NGINX_ENVSUBST_FILTER=API_ORIGIN|SUPABASE_ORIGIN
COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
