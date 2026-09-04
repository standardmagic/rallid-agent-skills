#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repository_root/skills/publish-blackrail-pages/scripts/blackrail-pages.sh"
draft="$repository_root/tests/fixtures/draft.json"
published="$repository_root/tests/fixtures/published.json"
test_directory="$(mktemp -d)"
export RALLID_TEST_CURL_ARGS="$test_directory/curl-args.txt"
export RALLID_TEST_CURL_META="$test_directory/curl-meta.txt"
export PATH="$repository_root/tests/fake-bin:$PATH"

staging_origin='https://staging.example.com'
staging_token='staging-test-token'
production_origin='https://www.example.com'
production_token='production-test-token'

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_no_secret_in_argv() {
  local secret="$1"
  if grep -F -- "$secret" "$RALLID_TEST_CURL_ARGS" >/dev/null; then
    fail "A bearer token appeared in curl process arguments."
  fi
}

assert_auth_file_cleaned() {
  local auth_file
  auth_file="$(sed -n 's/^authorization_file=//p' "$RALLID_TEST_CURL_META")"
  [[ -n "$auth_file" ]] || fail "Authenticated request did not use a header file."
  [[ ! -e "$auth_file" ]] || fail "Temporary authorization header file was not removed."
  grep -Fx -- 'authorization_mode=600' "$RALLID_TEST_CURL_META" >/dev/null \
    || fail "Temporary authorization header file was not mode 600."
}

malicious_origins=(
  'http://staging.example.com'
  'https://user@staging.example.com'
  'https://staging.example.com/admin'
  'https://staging.example.com?next=https://evil.example'
  'https://staging.example.com#fragment'
  'https://staging.example.com:8443'
  'https://127.0.0.1'
)
for malicious_origin in "${malicious_origins[@]}"; do
  if BLACKRAIL_SITE_URL="$malicious_origin" "$helper" list >/dev/null 2>&1; then
    fail "Malicious or non-canonical origin was accepted: $malicious_origin"
  fi
done

BLACKRAIL_SITE_URL='https://STAGING.EXAMPLE.COM:443/' \
  "$helper" list >/dev/null
grep -Fx -- 'https://staging.example.com/api/v1/pages' "$RALLID_TEST_CURL_ARGS" >/dev/null \
  || fail "A valid origin was not canonicalized."

BLACKRAIL_SITE_URL="$staging_origin" \
BLACKRAIL_API_TOKEN="$staging_token" \
RALLID_TEST_REJECT_PUBLIC_AUTH=1 \
  "$helper" list >/dev/null
grep -Fx -- 'authorization_present=false' "$RALLID_TEST_CURL_META" >/dev/null \
  || fail "Public list sent an authorization header."
assert_no_secret_in_argv "$staging_token"

check_output="$(
  BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
    "$helper" check
)"
printf '%s' "$check_output" | jq -e '.ok == true and .site_origin == "https://staging.example.com"' >/dev/null \
  || fail "Valid token check did not return the expected identity."
grep -Fx -- 'https://staging.example.com/api/v1/token' "$RALLID_TEST_CURL_ARGS" >/dev/null \
  || fail "Connection check did not use GET /api/v1/token."
assert_no_secret_in_argv "$staging_token"
assert_auth_file_cleaned

if BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
  RALLID_TEST_TOKEN_VALID=0 \
  "$helper" check >/dev/null 2>&1; then
  fail "Connection check accepted an invalid token."
fi

if BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
  RALLID_TEST_TOKEN_ORIGIN='https://other.example.com' \
  "$helper" check >/dev/null 2>&1; then
  fail "Connection check accepted a token for a different origin."
fi

if BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
  RALLID_TEST_TOKEN_SCOPES_JSON='["pages:read"]' \
  "$helper" check >/dev/null 2>&1; then
  fail "Connection check accepted a token without pages:edit."
fi

if BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
  "$helper" create-draft "$published" >/dev/null 2>&1; then
  fail "A published payload was accepted by create-draft."
fi

if BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN='https://different.example.com' \
  BLACKRAIL_API_TOKEN="$staging_token" \
  "$helper" create-draft "$draft" >/dev/null 2>&1; then
  fail "A draft write was sent to an origin that did not match its pin."
fi

draft_output="$(
  BLACKRAIL_SITE_URL="$staging_origin" \
  BLACKRAIL_APPROVED_SITE_ORIGIN="$staging_origin" \
  BLACKRAIL_API_TOKEN="$staging_token" \
    "$helper" create-draft "$draft"
)"
[[ "$draft_output" == '{"ok":true}' ]] || fail "Unexpected draft helper response."
grep -Fx -- 'POST' "$RALLID_TEST_CURL_ARGS" >/dev/null || fail "Draft did not use POST."
grep -Fx -- 'https://staging.example.com/api/v1/pages' "$RALLID_TEST_CURL_ARGS" >/dev/null \
  || fail "Draft used the wrong endpoint."
assert_no_secret_in_argv "$staging_token"
assert_auth_file_cleaned

published_hash="$(shasum -a 256 "$published" | awk '{print $1}')"
future_expiry="$(( $(date +%s) + 600 ))"
expired_at="$(( $(date +%s) - 1 ))"

if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-update' \
  BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
  BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$expired_at" \
  "$helper" publish-update test-page "$published" >/dev/null 2>&1; then
  fail "Production publication accepted an expired approval."
fi

mutated_payload="$test_directory/published-mutated.json"
cp "$published" "$mutated_payload"
printf '\n' >> "$mutated_payload"
if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-update' \
  BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
  BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
  "$helper" publish-update test-page "$mutated_payload" >/dev/null 2>&1; then
  fail "Production publication accepted payload bytes changed after approval."
fi

if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-new' \
  BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
  BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
  "$helper" publish-update test-page "$published" >/dev/null 2>&1; then
  fail "Production publication accepted a different operation than approved."
fi

if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-update' \
  BLACKRAIL_APPROVED_PAGE_SLUG='different-page' \
  BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
  "$helper" publish-update test-page "$published" >/dev/null 2>&1; then
  fail "Production publication accepted a different slug than approved."
fi

if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-update' \
  BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
  BLACKRAIL_APPROVED_ORIGIN='https://other.example.com' \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
  "$helper" publish-update test-page "$published" >/dev/null 2>&1; then
  fail "Production publication accepted a different origin than approved."
fi

if BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
  BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
  BLACKRAIL_APPROVED_OPERATION='publish-update' \
  BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
  BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
  BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
  BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
  RALLID_TEST_TOKEN_SCOPES_JSON='["pages:edit"]' \
  "$helper" publish-update test-page "$published" >/dev/null 2>&1; then
  fail "Production publication accepted a token without pages:publish."
fi

BLACKRAIL_PRODUCTION_SITE_URL="$production_origin" \
BLACKRAIL_PUBLISH_API_TOKEN="$production_token" \
BLACKRAIL_APPROVED_OPERATION='publish-update' \
BLACKRAIL_APPROVED_PAGE_SLUG='test-page' \
BLACKRAIL_APPROVED_ORIGIN="$production_origin" \
BLACKRAIL_APPROVED_PAYLOAD_SHA256="$published_hash" \
BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$future_expiry" \
RALLID_TEST_TOKEN_SCOPES_JSON='["pages:edit","pages:publish"]' \
  "$helper" publish-update test-page "$published" >/dev/null

grep -Fx -- 'PUT' "$RALLID_TEST_CURL_ARGS" >/dev/null || fail "Approved update did not use PUT."
grep -Fx -- 'https://www.example.com/api/v1/pages/test-page' "$RALLID_TEST_CURL_ARGS" >/dev/null \
  || fail "Approved update used the wrong endpoint."
assert_no_secret_in_argv "$production_token"
assert_auth_file_cleaned

printf 'Helper safety tests passed.\n'
