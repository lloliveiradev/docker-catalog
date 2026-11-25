# AWS publishes no image, so install the Linux package. Always the latest release:
# upgrade with `docker compose build --pull --no-cache`.
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal
ARG TARGETARCH

# The build stops unless the package is signed by the key published in the user guide.
RUN set -eu; \
  case "$TARGETARCH" in \
    arm64) pkg=aws-emulator-aarch64.rpm ;; \
    amd64) pkg=aws-emulator-x86_64.rpm ;; \
    *) echo "unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  base=https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest; \
  cd /tmp; \
  curl -fsSLO "$base/$pkg"; \
  curl -fsSLO "$base/$pkg.sig"; \
  curl -fsSLo aws.asc https://downloads.aws.com/keys/gpg/current.asc; \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --batch --dearmor < aws.asc > aws.gpg; \
  gpg --batch --no-autostart --no-default-keyring --keyring /tmp/aws.gpg --status-fd 1 \
    --verify "$pkg.sig" "$pkg" \
    | grep -E '^\[GNUPG:\] VALIDSIG .*98BCF336A3BE53B734E967C52E5BF49BD940F624'; \
  rpm -i "$pkg"; \
  rm -rf "$GNUPGHOME" /tmp/aws*; \
  mkdir -p /home/emulator; chown 1000 /home/emulator

USER 1000
# Listen on every address inside the container so Docker can forward the ports.
ENV HOME=/home/emulator PATH=/opt/aws-emulator/bin:$PATH EMULATOR_BIND_ADDRESS=0.0.0.0
EXPOSE 9297
ENTRYPOINT ["aws-emulator"]
