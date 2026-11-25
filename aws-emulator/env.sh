# Points the AWS CLI and SDKs of this shell at the local AWS Emulator. Source it (bash or zsh):
#   ( . ./env.sh && aws s3 ls )   one command; your shell stays as it was
#   . ./env.sh                    this shell, until you close it

# Running it would change nothing in the calling shell, which would keep its real credentials.
case ${ZSH_EVAL_CONTEXT:-} in
  *:file*) ;;
  '') (return 0 2>/dev/null) || { echo "Source this file: . ./env.sh" >&2; exit 1; } ;;
  *) echo "Source this file: . ./env.sh" >&2; exit 1 ;;
esac

# All the work happens in a function, so that no helper variable stays in your shell.
_emu_setup() {
  # First drop everything that could send a call to real AWS, so the shell is safe
  # even when a check below fails. The second group is read by older SDKs.
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN \
    AWS_PROFILE AWS_DEFAULT_PROFILE AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN AWS_ROLE_SESSION_NAME \
    AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_CONTAINER_CREDENTIALS_FULL_URI \
    AWS_CONTAINER_AUTHORIZATION_TOKEN AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE \
    AWS_IGNORE_CONFIGURED_ENDPOINT_URLS \
    AWS_ACCESS_KEY AWS_SECRET_KEY AMAZON_ACCESS_KEY_ID AMAZON_SECRET_ACCESS_KEY \
    AMAZON_SESSION_TOKEN AWS_CREDENTIAL_FILE

  local _name='' _src='' _link='' _dir='' _values='' _port='' _home='' _files='' \
    _problem='' _upper='' _lower='' _host=''

  # Per-service endpoint variables win over AWS_ENDPOINT_URL.
  for _name in $(env | sed -n 's/^\(AWS_ENDPOINT_URL_[A-Za-z0-9_]*\)=.*/\1/p'); do
    unset "$_name"
  done

  # The path of this file, whatever the shell options say about $0, with symlinks followed.
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval '_src=${(%):-%x}'
  else
    _src=${BASH_SOURCE[0]}
  fi
  while [ -L "$_src" ]; do
    _link=$(readlink "$_src")
    case $_link in
      /*) _src=$_link ;;
      *) _src=$(dirname -- "$_src")/$_link ;;
    esac
  done
  # Output from a cd wrapper or a directory-change hook must not end up in the path.
  _dir=$(CDPATH= builtin cd -- "$(dirname -- "$_src")" >/dev/null 2>&1 && pwd)

  # Compose is the authority on .env: quotes, `export`, ${VAR} and precedence over the shell.
  if [ -f "$_dir/.env" ]; then
    if _values=$(command docker compose --project-directory "$_dir" -f "$_dir/compose.yaml" \
      config --environment 2>&1); then
      _port=$(printf '%s\n' "$_values" | sed -n 's/^EMULATOR_PORT=//p')
      _home=$(printf '%s\n' "$_values" | sed -n 's/^EMULATOR_HOME=//p')
      _port=${_port:-9297}
    else
      _problem="Cannot read $_dir/.env, which needs Docker Compose 2.27.2 or newer: $_values"
      _port=1 # point nowhere rather than at whatever holds the default port
    fi
  else
    # Like Compose, look at exported variables only.
    _port=$(printenv EMULATOR_PORT || true)
    _home=$(printenv EMULATOR_HOME || true)
    _port=${_port:-9297}
  fi
  _files="${_home:-$HOME}/.aws/emulator/$_port"

  export AWS_ENDPOINT_URL="https://127.0.0.1:$_port"
  export AWS_CONFIG_FILE="$_files/config"
  export AWS_SHARED_CREDENTIALS_FILE="$_files/emulator_credentials"
  # Java SDK 1.x reads this name instead, and falls back to ~/.aws/credentials without it.
  export AWS_CREDENTIAL_PROFILES_FILE="$_files/emulator_credentials"
  export AWS_CA_BUNDLE="$_files/ca.pem"
  export NODE_EXTRA_CA_CERTS="$_files/ca.pem"
  export AWS_EC2_METADATA_DISABLED=true
  # Some operations would otherwise prefix the host name, as in data-127.0.0.1.
  export AWS_DISABLE_HOST_PREFIX_INJECTION=true
  export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
  export AWS_PAGER=""
  # Rust and .NET read SSL_CERT_FILE. It replaces the system certificates, so set it per command:
  #   SSL_CERT_FILE="$AWS_CA_BUNDLE" cargo test

  # Calls to the emulator must not go through a proxy. A lone * already covers it.
  _upper=${NO_PROXY:-${no_proxy:-}}
  _lower=${no_proxy:-${NO_PROXY:-}}
  for _host in 127.0.0.1 localhost; do
    case ",$_upper," in ,\*, | *",$_host,"*) ;; *) _upper=${_upper:+$_upper,}$_host ;; esac
    case ",$_lower," in ,\*, | *",$_host,"*) ;; *) _lower=${_lower:+$_lower,}$_host ;; esac
  done
  export NO_PROXY="$_upper" no_proxy="$_lower"

  if [ -z "$_problem" ]; then
    if [ ! -f "$AWS_SHARED_CREDENTIALS_FILE" ]; then
      _problem="AWS Emulator is not running on port $_port: no $AWS_SHARED_CREDENTIALS_FILE"
    # A killed emulator leaves its files behind, so ask it.
    elif ! curl -sf --noproxy '*' --max-time 3 --cacert "$AWS_CA_BUNDLE" \
      "$AWS_ENDPOINT_URL/__admin/health" >/dev/null 2>&1; then
      _problem="AWS Emulator does not answer on $AWS_ENDPOINT_URL"
    fi
  fi
  [ -z "$_problem" ] && return 0
  printf '%s\nStart it: cd "%s" && docker compose up -d --wait\n' "$_problem" "$_dir" >&2
  return 1
}

if _emu_setup; then
  unset -f _emu_setup
else
  unset -f _emu_setup
  return 1
fi
