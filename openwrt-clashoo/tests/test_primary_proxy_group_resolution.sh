#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RESOLVER="$ROOT/clashoo/files/usr/share/clashoo/runtime/primary_group.sh"
IPRULES="$ROOT/clashoo/files/usr/share/clashoo/runtime/iprules.sh"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/clashoo-primary-group-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

assert_eq() {
	[ "$1" = "$2" ] || {
		echo "FAIL: expected '$1', got '$2'" >&2
		exit 1
	}
}

write_yaml() {
	printf '%s\n' "$1" >"$TEST_DIR/config.yaml"
}

. "$RESOLVER"

write_yaml 'proxy-groups:
  - name: Old Group
    type: select
  - name: Other Group
    type: select'
assert_eq 'Old Group' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Old Group')"
assert_eq 'GLOBAL' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'GLOBAL')"

write_yaml 'proxy-groups:
  - name: Automatic
    type: url-test
  - name: 🚀 节点选择
    type: select
  - name: Backup
    type: select'
assert_eq '🚀 节点选择' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Stale Group')"

write_yaml 'proxy-groups:
  - name: Fast PROXY
    type: SELECT
  - name: Backup
    type: select'
assert_eq 'Fast PROXY' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Stale Group')"

write_yaml 'proxy-groups:
  - name: Automatic
    type: url-test
  - name: First Choice
    type: select
  - name: Second Choice
    type: select'
assert_eq 'First Choice' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Stale Group')"

write_yaml 'proxy-groups:
  - name: Automatic
    type: url-test'
assert_eq 'GLOBAL' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Stale Group')"

write_yaml 'proxy-groups: ['
assert_eq 'GLOBAL' "$(clashoo_resolve_primary_group "$TEST_DIR/config.yaml" 'Stale Group')"
assert_eq 'GLOBAL' "$(clashoo_resolve_primary_group "$TEST_DIR/missing.yaml" 'Stale Group')"

grep -Fq 'clashoo_resolve_primary_group "$CONFIG_YAML" "$CACHED_PRIMARY_GROUP"' "$IPRULES"

echo "PASS: primary proxy group resolution"
