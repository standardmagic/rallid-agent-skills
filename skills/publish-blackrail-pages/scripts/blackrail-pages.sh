#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

canonicalize_https_origin() {
  local value="$1"
  local authority host port canonical_host label
  local labels=()

  [[ -n "$value" ]] || die "Site origin is required."
  case "$value" in
    *$'\n'*|*$'\r'*|*$'\t'*|*' '*) die "Site origin contains whitespace." ;;
  esac
  [[ "$value" == https://* ]] || die "Site origin must use HTTPS."
  [[ "$value" != *'?'* ]] || die "Site origin must not include a query string."
  [[ "$value" != *'#'* ]] || die "Site origin must not include a fragment."
  [[ "$value" != *'@'* ]] || die "Site origin must not include user information."

  value="${value%/}"
  authority="${value#https://}"
  [[ -n "$authority" && "$authority" != */* ]] || die "Site origin must not include a path."

  host="$authority"
  port=""
  if [[ "$authority" == *:* ]]; then
    [[ "$authority" != *:*:* ]] || die "Site origin must use a DNS hostname, not an IP literal."
    host="${authority%%:*}"
    port="${authority##*:}"
    [[ "$port" == "443" ]] || die "Site origin must not include a non-default port."
  fi

  canonical_host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
  [[ ${#canonical_host} -le 253 ]] || die "Site origin hostname is too long."
  [[ "$canonical_host" == *.* ]] || die "Site origin must use a fully qualified DNS hostname."
  [[ "$canonical_host" != .* && "$canonical_host" != *. && "$canonical_host" != *..* ]] || die "Site origin hostname is invalid."

  IFS='.' read -r -a labels <<< "$canonical_host"
  for label in "${labels[@]}"; do
    [[ ${#label} -ge 1 && ${#label} -le 63 ]] || die "Site origin hostname is invalid."
    [[ "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || die "Site origin hostname is invalid."
  done
  [[ ! "$canonical_host" =~ ^[0-9.]+$ ]] || die "Site origin must use a DNS hostname, not an IP literal."

  printf 'https://%s\n' "$canonical_host"
}

validate_token_value() {
  local token="$1"
  [[ ${#token} -ge 16 && ${#token} -le 512 ]] || die "API token has an invalid length."
  [[ "$token" =~ ^[A-Za-z0-9._~-]+$ ]] || die "API token has an invalid format."
}

emit_successful_response() {
  local response="$1"
  local http_status body

  [[ "$response" == *$'\n'* ]] || die "BlackRail response did not include an HTTP status."
  http_status="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^2[0-9][0-9]$ ]]; then
    [[ -z "$body" ]] || printf '%s\n' "$body" >&2
    die "BlackRail returned HTTP ${http_status}."
  fi
  printf '%s\n' "$body"
}

request_public() {
  local method="$1"
  local site_origin="$2"
  local path="$3"
  local response

  response="$(curl --disable \
    --silent --show-error --fail-with-body \
    --proto '=https' \
    --request "$method" \
    --header 'Accept: application/json' \
    --write-out $'\n%{http_code}' \
    "${site_origin}${path}")"
  emit_successful_response "$response"
}

request_authenticated() (
  set -euo pipefail
  local method="$1"
  local site_origin="$2"
  local token="$3"
  local path="$4"
  local payload_file="${5:-}"
  local blackrail_header_file
  local response
  local args=(
    --silent --show-error --fail-with-body
    --request "$method"
    --header 'Accept: application/json'
  )

  validate_token_value "$token"
  umask 077
  blackrail_header_file="$(mktemp "${TMPDIR:-/tmp}/rallid-auth-header.XXXXXX")"
  chmod 600 "$blackrail_header_file"
  trap 'rm -f -- "$blackrail_header_file"' EXIT
  printf 'Authorization: Bearer %s\n' "$token" > "$blackrail_header_file"
  args+=(--header "@${blackrail_header_file}")

  if [[ -n "$payload_file" ]]; then
    [[ -f "$payload_file" ]] || die "Payload file not found: $payload_file"
    args+=(--header 'Content-Type: application/json' --data-binary "@${payload_file}")
  fi

  response="$(curl --disable --proto '=https' "${args[@]}" --write-out $'\n%{http_code}' "${site_origin}${path}")"
  emit_successful_response "$response"
)

require_pinned_staging() {
  local site_origin approved_origin
  : "${BLACKRAIL_SITE_URL:?Set BLACKRAIL_SITE_URL to the BlackRail staging origin.}"
  : "${BLACKRAIL_APPROVED_SITE_ORIGIN:?Set BLACKRAIL_APPROVED_SITE_ORIGIN to the exact staging origin shown by Rallid.}"
  site_origin="$(canonicalize_https_origin "$BLACKRAIL_SITE_URL")"
  approved_origin="$(canonicalize_https_origin "$BLACKRAIL_APPROVED_SITE_ORIGIN")"
  [[ "$site_origin" == "$approved_origin" ]] || die "BLACKRAIL_SITE_URL does not match BLACKRAIL_APPROVED_SITE_ORIGIN."
  printf '%s\n' "$site_origin"
}

require_staging_token() {
  : "${BLACKRAIL_API_TOKEN:?Set BLACKRAIL_API_TOKEN to a short-lived staging token.}"
  validate_token_value "$BLACKRAIL_API_TOKEN"
}

validate_json_payload() {
  local payload_file="$1"
  [[ -f "$payload_file" ]] || die "Payload file not found: $payload_file"
  jq empty "$payload_file" >/dev/null || die "Payload must be valid JSON: $payload_file"
}

payload_field() {
  local payload_file="$1"
  local field="$2"
  jq -er --arg field "$field" '.[$field] | select(type == "string" and length > 0)' "$payload_file" \
    || die "Payload field '$field' must be a non-empty string."
}

validate_token_check_response() {
  local response="$1"
  local expected_origin="$2"
  local server_origin required_scope
  shift 2

  printf '%s' "$response" | jq -e '
    .ok == true
    and (.site_name | type == "string" and length > 0)
    and (.site_origin | type == "string" and length > 0)
    and (.scopes | type == "array")
    and (.expires_at | type == "string" and length > 0)
  ' >/dev/null || die "Token check returned an invalid response."

  server_origin="$(printf '%s' "$response" | jq -er '.site_origin')"
  server_origin="$(canonicalize_https_origin "$server_origin")"
  [[ "$server_origin" == "$expected_origin" ]] || die "Token belongs to a different site origin."

  for required_scope in "$@"; do
    printf '%s' "$response" | jq -e --arg scope "$required_scope" '.scopes | index($scope) != null' >/dev/null \
      || die "Token is missing the required '$required_scope' scope."
  done
}

payload_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

validate_production_review_guardrail() {
  local operation="$1"
  local slug="$2"
  local payload_file="$3"
  local production_origin="$4"
  local approved_origin approved_hash actual_hash expires_at now maximum_expiry

  : "${BLACKRAIL_APPROVED_OPERATION:?Set BLACKRAIL_APPROVED_OPERATION to the exact approved publish command.}"
  : "${BLACKRAIL_APPROVED_PAGE_SLUG:?Set BLACKRAIL_APPROVED_PAGE_SLUG to the exact approved page slug.}"
  : "${BLACKRAIL_APPROVED_ORIGIN:?Set BLACKRAIL_APPROVED_ORIGIN to the exact approved production origin.}"
  : "${BLACKRAIL_APPROVED_PAYLOAD_SHA256:?Set BLACKRAIL_APPROVED_PAYLOAD_SHA256 to the SHA-256 of the reviewed payload bytes.}"
  : "${BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH:?Set BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH to a Unix timestamp no more than one hour ahead.}"

  [[ "$operation" == "$BLACKRAIL_APPROVED_OPERATION" ]] || die "Operation does not match BLACKRAIL_APPROVED_OPERATION."
  [[ "$slug" == "$BLACKRAIL_APPROVED_PAGE_SLUG" ]] || die "Page slug does not match BLACKRAIL_APPROVED_PAGE_SLUG."

  approved_origin="$(canonicalize_https_origin "$BLACKRAIL_APPROVED_ORIGIN")"
  [[ "$production_origin" == "$approved_origin" ]] || die "Production origin does not match BLACKRAIL_APPROVED_ORIGIN."

  approved_hash="$(printf '%s' "$BLACKRAIL_APPROVED_PAYLOAD_SHA256" | tr '[:upper:]' '[:lower:]')"
  [[ "$approved_hash" =~ ^[a-f0-9]{64}$ ]] || die "BLACKRAIL_APPROVED_PAYLOAD_SHA256 must be a SHA-256 hex digest."
  actual_hash="$(payload_sha256 "$payload_file")"
  [[ "$actual_hash" == "$approved_hash" ]] || die "Payload bytes changed after approval."

  expires_at="$BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH"
  [[ "$expires_at" =~ ^[0-9]+$ && ${#expires_at} -le 12 ]] || die "BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH must be a Unix timestamp."
  expires_at="$((10#$expires_at))"
  now="$(date +%s)"
  maximum_expiry="$((now + 3600))"
  (( expires_at > now )) || die "Production approval has expired."
  (( expires_at <= maximum_expiry )) || die "Production approval must expire within one hour."
}

usage() {
  cat <<'EOF'
Usage:
  blackrail-pages.sh check
  blackrail-pages.sh list
  blackrail-pages.sh get <slug>
  blackrail-pages.sh create-draft <payload.json>
  blackrail-pages.sh update-draft <slug> <payload.json>
  blackrail-pages.sh publish-new <payload.json>
  blackrail-pages.sh publish-update <slug> <payload.json>

Public list needs BLACKRAIL_SITE_URL and sends no bearer token.
Connection checks and staging writes also require BLACKRAIL_APPROVED_SITE_ORIGIN
and BLACKRAIL_API_TOKEN. The check uses GET /api/v1/token.

Production publication requires BLACKRAIL_PRODUCTION_SITE_URL,
BLACKRAIL_PUBLISH_API_TOKEN, and a short-lived local review guardrail binding
BLACKRAIL_APPROVED_OPERATION, BLACKRAIL_APPROVED_PAGE_SLUG,
BLACKRAIL_APPROVED_ORIGIN, BLACKRAIL_APPROVED_PAYLOAD_SHA256, and
BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH. The scoped token remains the server-side
authorization boundary.
EOF
}

command_name="${1:-}"
case "$command_name" in
  check)
    [[ $# -eq 1 ]] || die "check takes no arguments."
    require_command curl
    require_command jq
    staging_origin="$(require_pinned_staging)"
    require_staging_token
    token_check_response="$(request_authenticated GET "$staging_origin" "$BLACKRAIL_API_TOKEN" '/api/v1/token')" \
      || die "Token validation failed."
    validate_token_check_response "$token_check_response" "$staging_origin" pages:read pages:edit
    printf '%s\n' "$token_check_response"
    ;;
  list)
    [[ $# -eq 1 ]] || die "list takes no arguments."
    require_command curl
    : "${BLACKRAIL_SITE_URL:?Set BLACKRAIL_SITE_URL to the BlackRail site origin.}"
    public_origin="$(canonicalize_https_origin "$BLACKRAIL_SITE_URL")"
    request_public GET "$public_origin" '/api/v1/pages'
    ;;
  get)
    [[ $# -eq 2 ]] || die "get requires a page slug."
    require_command curl
    require_command jq
    : "${BLACKRAIL_SITE_URL:?Set BLACKRAIL_SITE_URL to the BlackRail site origin.}"
    public_origin="$(canonicalize_https_origin "$BLACKRAIL_SITE_URL")"
    slug="$(jq -rn --arg value "$2" '$value|@uri')"
    request_public GET "$public_origin" "/api/v1/pages/${slug}"
    ;;
  create-draft)
    [[ $# -eq 2 ]] || die "create-draft requires a JSON payload file."
    require_command curl
    require_command jq
    staging_origin="$(require_pinned_staging)"
    require_staging_token
    validate_json_payload "$2"
    [[ "$(payload_field "$2" status)" == "draft" ]] || die 'Staging payload status must be "draft".'
    payload_field "$2" slug >/dev/null
    request_authenticated POST "$staging_origin" "$BLACKRAIL_API_TOKEN" '/api/v1/pages' "$2"
    ;;
  update-draft)
    [[ $# -eq 3 ]] || die "update-draft requires a page slug and JSON payload file."
    require_command curl
    require_command jq
    staging_origin="$(require_pinned_staging)"
    require_staging_token
    validate_json_payload "$3"
    [[ "$(payload_field "$3" status)" == "draft" ]] || die 'Staging payload status must be "draft".'
    [[ "$(payload_field "$3" slug)" == "$2" ]] || die "Payload slug does not match the update route slug."
    slug="$(jq -rn --arg value "$2" '$value|@uri')"
    request_authenticated PUT "$staging_origin" "$BLACKRAIL_API_TOKEN" "/api/v1/pages/${slug}" "$3"
    ;;
  publish-new|publish-update)
    require_command curl
    require_command jq
    require_command shasum
    if [[ "$command_name" == "publish-new" ]]; then
      [[ $# -eq 2 ]] || die "publish-new requires a JSON payload file."
      payload_file="$2"
      validate_json_payload "$payload_file"
      slug="$(payload_field "$payload_file" slug)"
    else
      [[ $# -eq 3 ]] || die "publish-update requires a page slug and JSON payload file."
      slug="$2"
      payload_file="$3"
      validate_json_payload "$payload_file"
      [[ "$(payload_field "$payload_file" slug)" == "$slug" ]] || die "Payload slug does not match the update route slug."
    fi

    : "${BLACKRAIL_PRODUCTION_SITE_URL:?Set BLACKRAIL_PRODUCTION_SITE_URL to the approved production origin.}"
    : "${BLACKRAIL_PUBLISH_API_TOKEN:?Set BLACKRAIL_PUBLISH_API_TOKEN to a short-lived production publishing token.}"
    production_origin="$(canonicalize_https_origin "$BLACKRAIL_PRODUCTION_SITE_URL")"
    validate_token_value "$BLACKRAIL_PUBLISH_API_TOKEN"
    [[ "$(payload_field "$payload_file" status)" == "published" ]] || die 'Production payload status must be "published".'
    validate_production_review_guardrail "$command_name" "$slug" "$payload_file" "$production_origin"
    production_token_check="$(request_authenticated GET "$production_origin" "$BLACKRAIL_PUBLISH_API_TOKEN" '/api/v1/token')" \
      || die "Production token validation failed."
    validate_token_check_response "$production_token_check" "$production_origin" pages:edit pages:publish

    if [[ "$command_name" == "publish-new" ]]; then
      request_authenticated POST "$production_origin" "$BLACKRAIL_PUBLISH_API_TOKEN" '/api/v1/pages' "$payload_file"
    else
      encoded_slug="$(jq -rn --arg value "$slug" '$value|@uri')"
      request_authenticated PUT "$production_origin" "$BLACKRAIL_PUBLISH_API_TOKEN" "/api/v1/pages/${encoded_slug}" "$payload_file"
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
