FROM docker:29-dind

ARG TERRAFORM_VERSION=1.17.1
ARG KIND_VERSION=0.30.0
ARG KUBECTL_VERSION=1.37.1
ARG TARGETARCH

RUN apk add --no-cache bash curl unzip make \
    && case "${TARGETARCH}" in \
         amd64) terraform_arch=amd64; kind_arch=amd64 ;; \
         arm64) terraform_arch=arm64; kind_arch=arm64 ;; \
         *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSLo /tmp/terraform.zip \
       "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && curl -fsSLo /usr/local/bin/kind \
       "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${kind_arch}" \
    && curl -fsSLo /usr/local/bin/kubectl \
       "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${kind_arch}/kubectl" \
    && chmod +x /usr/local/bin/terraform /usr/local/bin/kind /usr/local/bin/kubectl \
    && rm -f /tmp/terraform.zip

WORKDIR /workspace

