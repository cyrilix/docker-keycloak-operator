FROM --platform=$BUILDPLATFORM golang:1.17 as builder-src

ARG BUILDPLATFORM
ARG KEYCLOAK_OPERATOR_VERSION=15.1.0

COPY ./go-autoneg /workspace/go-autoneg

WORKDIR /workspace
RUN git clone https://github.com/keycloak/keycloak-operator.git

WORKDIR /workspace/keycloak-operator
RUN git checkout ${KEYCLOAK_OPERATOR_VERSION}

RUN echo "replace bitbucket.org/ww/goautoneg => ../go-autoneg" >> go.mod && \
    go mod vendor



FROM --platform=$BUILDPLATFORM builder-src as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} CGO_ENABLED=0 GO111MODULE=on go build -mod=vendor -a -installsuffix cgo -o keycloak-operator ./cmd/manager



# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:latest

WORKDIR /
COPY --from=builder /workspace/keycloak-operator/keycloak-operator /usr/local/bin/

USER 1234
ENTRYPOINT ["/usr/local/bin/keycloak-operator"]

