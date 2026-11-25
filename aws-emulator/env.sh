# Points the AWS CLI and SDKs of this shell at the local AWS Emulator. Source it (bash or zsh):
#   ( . ./env.sh && aws s3 ls )   one command; your shell stays as it was
#   . ./env.sh                    this shell, until you close it

# Running it would change nothing in the calling shell, which would keep its real credentials.
case ${ZSH_EVAL_CONTEXT:-} in
  *:file*) ;;
  '') (return 0 2>/dev/null) || { echo "Source this file: . ./env.sh" >&2; exit 1; } ;;
  *) echo "Source this file: . ./env.sh" >&2; exit 1 ;;
esac

# First drop everything that could send a call to real AWS, so the shell is safe
# even when a check below fails. The second group is read by older SDKs.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN \
  AWS_PROFILE AWS_DEFAULT_PROFILE AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN AWS_ROLE_SESSION_NAME \
  AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_CONTAINER_CREDENTIALS_FULL_URI \
  AWS_CONTAINER_AUTHORIZATION_TOKEN AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE \
  AWS_IGNORE_CONFIGURED_ENDPOINT_URLS \
  AWS_ACCESS_KEY AWS_SECRET_KEY AMAZON_ACCESS_KEY_ID AMAZON_SECRET_ACCESS_KEY \
  AMAZON_SESSION_TOKEN AWS_CREDENTIAL_FILE
# Per-service endpoint variables win over AWS_ENDPOINT_URL.
for _emu_name in $(env | sed -n 's/^\(AWS_ENDPOINT_URL_[A-Za-z0-9_]*\)=.*/\1/p'); do
  unset "$_emu_name"
done

# Output from a cd wrapper or a directory-change hook must not end up in the path.
_emu_dir=$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE:-$0}")" >/dev/null 2>&1 && pwd)

# Same precedence as Compose: the shell variable, then .env, then the default.
_emu_setting() { # name, default
  eval "_emu_value=\${$1:-}"
  if [ -z "$_emu_value" ] && [ -f "$_emu_dir/.env" ]; then
    _emu_value=$(tr -d '\r' <"$_emu_dir/.env" | sed -n "s/^$1=//p" | tail -n 1 |
      sed -e 's/^"\([^"]*\)".*/\1/' -e t -e "s/^'\([^']*\)'.*/\1/" -e t \
        -e 's/[[:space:]]#.*//' -e 's/[[:space:]]*$//')
  fi
  printf '%s' "${_emu_value:-$2}"
}

_emu_port=$(_emu_setting EMULATOR_PORT 9297)
_emu_files="$(_emu_setting EMULATOR_HOME "$HOME")/.aws/emulator/$_emu_port"
unset -f _emu_setting

export AWS_ENDPOINT_URL="https://127.0.0.1:$_emu_port"
export AWS_CONFIG_FILE="$_emu_files/config"
export AWS_SHARED_CREDENTIALS_FILE="$_emu_files/emulator_credentials"
# Java SDK 1.x reads this name instead, and falls back to ~/.aws/credentials without it.
export AWS_CREDENTIAL_PROFILES_FILE="$_emu_files/emulator_credentials"
export AWS_CA_BUNDLE="$_emu_files/ca.pem"
export NODE_EXTRA_CA_CERTS="$_emu_files/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""
# Rust and .NET read SSL_CERT_FILE. It replaces the system certificates, so set it per command:
#   SSL_CERT_FILE="$AWS_CA_BUNDLE" cargo test

if [ ! -f "$AWS_SHARED_CREDENTIALS_FILE" ]; then
  echo "AWS Emulator is not running on port $_emu_port: no $AWS_SHARED_CREDENTIALS_FILE" >&2
  echo "Start it: cd \"$_emu_dir\" && docker compose up -d --wait" >&2
  unset _emu_name _emu_dir _emu_port _emu_files
  return 1
fi
# A killed emulator leaves its files behind, so ask it.
if ! curl -sf --noproxy '*' --max-time 3 --cacert "$AWS_CA_BUNDLE" \
  "$AWS_ENDPOINT_URL/__admin/health" >/dev/null 2>&1; then
  echo "AWS Emulator does not answer on $AWS_ENDPOINT_URL" >&2
  echo "Start it: cd \"$_emu_dir\" && docker compose up -d --wait" >&2
  unset _emu_name _emu_dir _emu_port _emu_files
  return 1
fi
unset _emu_name _emu_dir _emu_port _emu_files
