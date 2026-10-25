#!/usr/bin/env bash
# Local + CI validation: promtool lint and unit tests for the SLO rules,
# and structural checks for the dashboard JSON.
# Needs: yq (mikefarah v4), promtool, jq.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf build && mkdir -p build/rules
for f in config/rules/*.yaml; do
  yq '.spec' "$f" > "build/rules/$(basename "$f")"
done
echo "--- promtool check rules"
promtool check rules build/rules/*.yaml
echo "--- promtool test rules"
promtool test rules tests/*.yaml

echo "--- dashboards"
fail=0
for d in config/dashboards/*/*.json; do
  jq empty "$d" || { echo "invalid JSON: $d"; fail=1; continue; }
  jq -e '(.uid|type=="string" and length>0) and (.title|type=="string") and (.panels|length>0)' "$d" >/dev/null \
    || { echo "missing uid/title/panels: $d"; fail=1; }
  # every panel must use one of the provisioned datasource uids
  bad=$(jq -r '[.panels[] | select(.type!="row") | .datasource.uid] | map(select(. != "prometheus" and . != "loki")) | length' "$d")
  [[ "$bad" == 0 ]] || { echo "unknown datasource uid in $d"; fail=1; }
  # panel ids must be unique
  dup=$(jq '[.panels[].id] | length - (unique|length)' "$d")
  [[ "$dup" == 0 ]] || { echo "duplicate panel ids in $d"; fail=1; }
  echo "ok  $d"
done
# dashboard uids must be unique across the repo
dups=$(jq -r '.uid' config/dashboards/*/*.json | sort | uniq -d)
[[ -z "$dups" ]] || { echo "duplicate dashboard uid(s): $dups"; fail=1; }
exit $fail
