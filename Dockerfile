# Build the manager binary
FROM --platform=$BUILDPLATFORM golang:1.15 as builder-src

ARG KEYCLOAK_OPERATOR_VERSION=11.0.2

COPY ./go-autoneg /workspace/go-autoneg

WORKDIR /workspace
RUN git clone https://github.com/keycloak/keycloak-operator.git

WORKDIR /workspace/keycloak-operator
RUN git checkout ${KEYCLOAK_OPERATOR_VERSION}

# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer

RUN echo "replace bitbucket.org/ww/goautoneg => ../go-autoneg" >> go.mod && \
    go mod vendor


FROM --platform=$BUILDPLATFORM builder-src as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    GOARCH=${GOARCH} GOARM=${GOARM} go mod vendor && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -mod=vendor -a -o keycloak-operator ./cmd/manager

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:latest
WORKDIR /
COPY --from=builder /workspace/keycloak-operator/keycloak-operator .
ENTRYPOINT ["/keycloak-operator"]

