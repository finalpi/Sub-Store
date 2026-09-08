FROM node:24-alpine AS backend-builder

WORKDIR /src/backend
RUN corepack enable

COPY backend/package.json backend/pnpm-lock.yaml ./
COPY backend/pnpm-workspace.yaml ./
COPY backend/patches ./patches
RUN pnpm install --no-frozen-lockfile

COPY backend/ ./
RUN pnpm test && pnpm bundle:esbuild


FROM alpine:3.22 AS frontend-downloader

ARG FRONTEND_VERSION
RUN apk add --no-cache ca-certificates curl unzip \
    && test -n "$FRONTEND_VERSION" \
    && curl -fsSL \
        "https://github.com/sub-store-org/Sub-Store-Front-End/releases/download/${FRONTEND_VERSION}/dist.zip" \
        -o /tmp/frontend.zip \
    && unzip -q /tmp/frontend.zip -d /tmp \
    && test -f /tmp/dist/index.html \
    && mv /tmp/dist /frontend


FROM node:24-alpine

ARG TARGETARCH=amd64
ARG FRONTEND_VERSION

LABEL org.opencontainers.image.title="Sub-Store" \
      org.opencontainers.image.description="Sub-Store backend and official frontend" \
      org.opencontainers.image.source="https://github.com/finalpi/Sub-Store" \
      org.opencontainers.image.frontend.version="$FRONTEND_VERSION"

ENV TZ=Asia/Shanghai

RUN apk add --no-cache ca-certificates curl tar tzdata \
    && cp "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && curl -fsSL \
        "https://github.com/containrrr/shoutrrr/releases/latest/download/shoutrrr_linux_${TARGETARCH}.tar.gz" \
        -o /tmp/shoutrrr.tar.gz \
    && tar -xzf /tmp/shoutrrr.tar.gz -C /usr/local/bin shoutrrr \
    && chmod 0755 /usr/local/bin/shoutrrr \
    && rm -f /tmp/shoutrrr.tar.gz

WORKDIR /opt/app

COPY --from=backend-builder /src/backend/dist/sub-store.bundle.js ./sub-store.bundle.js
COPY --from=frontend-downloader /frontend ./frontend

RUN mkdir -p /opt/app/data

EXPOSE 3001

CMD ["/bin/sh", "-c", "cd /opt/app/data && SUB_STORE_DOCKER=true SUB_STORE_FRONTEND_PATH=/opt/app/frontend SUB_STORE_DATA_BASE_PATH=/opt/app/data node /opt/app/sub-store.bundle.js"]
