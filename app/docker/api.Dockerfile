# syntax=docker/dockerfile:1.7
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY app/api/go.mod app/api/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY app/api/ .
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/mural-api .

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/mural-api /mural-api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/mural-api"]

