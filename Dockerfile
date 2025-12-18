# --- build ---
FROM swift:6.0-jammy as build
WORKDIR /app
COPY Package.* ./
RUN swift package resolve
COPY . .
RUN swift build -c release --static-swift-stdlib

# --- run ---
FROM ubuntu:22.04
WORKDIR /run
RUN apt-get update && apt-get install -y ca-certificates curl tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/.build/release/Run /run/Run
ENV HOST=0.0.0.0 PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD curl -fsS http://127.0.0.1:${PORT}/health || exit 1
ENTRYPOINT ["/run/Run"]
