#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  GATE="$REPO_ROOT/dot_local/bin/executable_self-review-gate"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  CHECKOUT="$TEST_HOME/checkout"
  HEAD_SHA="aaaaaaaa11112222333344445555666677778888"
  mkdir -p "$CHECKOUT/.agents-code-review/runs" "$TEST_HOME/bin"
  export PATH="$TEST_HOME/bin:$PATH"

  # gh prints the PR view it was asked for, or fails when GH_STUB_FAIL is set.
  cat >"$TEST_HOME/bin/gh" <<EOF
#!/usr/bin/env bash
[ -z "\${GH_STUB_FAIL:-}" ] || exit 1
printf '%s\n' "\$*" >>"$TEST_HOME/gh.log"
printf '{"number": 7, "headRefOid": "$HEAD_SHA"}\n'
EOF
  chmod +x "$TEST_HOME/bin/gh"
}

teardown() {
  rm -rf "${TEST_HOME:-}"
}

# add_run <name> <pr> <sha> <findings> <status> [failed_roles] [reviewed_at]
add_run() {
  mkdir -p "$CHECKOUT/.agents-code-review/runs/$1"
  jq -n --arg pr "$2" --arg sha "$3" --argjson count "$4" --arg status "$5" \
    --arg failed "${6:-}" --arg at "${7:-2026-10-31T10:00:00.000Z}" '{
      status: $status,
      findings: [range($count) | {id: "f\(.)"}],
      metadata: {
        pr_number: $pr, pr_reviewed_head_sha: $sha, pr_reviewed_at: $at,
        failed_roles: $failed, timed_out_roles: ""
      }
    }' >"$CHECKOUT/.agents-code-review/runs/$1/result.json"
}

gate() {
  local input
  input="$(jq -n --arg command "$1" --arg cwd "$CHECKOUT" \
    '{tool_input: {command: $command}, cwd: $cwd}')"
  run bash -c 'printf "%s" "$1" | bash "$2" "$3"' bash "$input" "$GATE" "${2:-claude}"
}

decision() {
  jq -r '.hookSpecificOutput.permissionDecision' <<<"$output"
}

reason() {
  jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$output"
}

@test "a clean review of the current head passes silently" {
  add_run r1 7 "$HEAD_SHA" 0 passed
  gate 'gh pr ready 7'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no review at all is denied" {
  gate 'gh pr ready 7'
  [ "$status" -eq 0 ]
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *"self-review-checks"* ]]
}

@test "a review of an older head is denied" {
  add_run r1 7 "bbbbbbbb11112222333344445555666677778888" 0 passed
  gate 'gh pr ready 7'
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *"aaaaaaaa"* ]]
}

@test "the same head reviewed under another PR number is denied" {
  add_run r1 8 "$HEAD_SHA" 0 passed
  gate 'gh pr ready 7'
  [ "$(decision)" = "deny" ]
}

@test "findings left on a passed run ask the operator" {
  add_run r1 7 "$HEAD_SHA" 2 passed
  gate 'gh pr ready 7'
  [ "$(decision)" = "ask" ]
  [[ "$(reason)" == *"2 finding"* ]]
}

@test "the newest review of a head decides" {
  add_run r1 7 "$HEAD_SHA" 2 passed "" "2026-10-31T10:00:00.000Z"
  add_run r2 7 "$HEAD_SHA" 0 passed "" "2026-10-31T11:00:00.000Z"
  gate 'gh pr ready 7'
  [ -z "$output" ]
}

@test "a review with failed roles asks the operator" {
  add_run r1 7 "$HEAD_SHA" 0 passed security
  gate 'gh pr ready 7'
  [ "$(decision)" = "ask" ]
}

@test "a run that did not pass asks the operator" {
  add_run r1 7 "$HEAD_SHA" 0 failed
  gate 'gh pr ready 7'
  [ "$(decision)" = "ask" ]
}

@test "unreadable review output asks the operator" {
  mkdir -p "$CHECKOUT/.agents-code-review/runs/r1"
  printf '%s not json' "$HEAD_SHA" >"$CHECKOUT/.agents-code-review/runs/r1/result.json"
  gate 'gh pr ready 7'
  [ "$(decision)" = "ask" ]
}

@test "a gh failure asks the operator" {
  export GH_STUB_FAIL=1
  gate 'gh pr ready 7'
  [ "$(decision)" = "ask" ]
}

@test "the repo flag reaches gh and a missing selector uses the current branch" {
  add_run r1 7 "$HEAD_SHA" 0 passed
  gate 'gh pr ready 7 -R owner/repo'
  [ -z "$output" ]
  grep -q 'pr view 7 -R owner/repo --json' "$TEST_HOME/gh.log"

  gate 'gh pr ready'
  [ -z "$output" ]
  grep -q '^pr view --json' "$TEST_HOME/gh.log"
}

@test "review output is found from a subdirectory and after cd" {
  add_run r1 7 "$HEAD_SHA" 0 passed
  mkdir -p "$CHECKOUT/src"
  local input
  input="$(jq -n --arg cwd "$CHECKOUT/src" '{tool_input: {command: "gh pr ready 7"}, cwd: $cwd}')"
  run bash -c 'printf "%s" "$1" | bash "$2" claude' bash "$input" "$GATE"
  [ -z "$output" ]

  input="$(jq -n --arg command "cd $CHECKOUT && gh pr ready 7" '{tool_input: {command: $command}, cwd: "/"}')"
  run bash -c 'printf "%s" "$1" | bash "$2" claude' bash "$input" "$GATE"
  [ -z "$output" ]

  input='{"tool_input": {"command": "cd ~/checkout; gh pr ready 7"}, "cwd": "/"}'
  run bash -c 'printf "%s" "$1" | bash "$2" claude' bash "$input" "$GATE"
  [ -z "$output" ]
}

@test "every PR in a compound command is checked" {
  add_run r1 7 "$HEAD_SHA" 0 passed
  gate 'gh pr ready 7; gh pr ready 8'
  [ -z "$output" ]
  [ "$(grep -c 'pr view' "$TEST_HOME/gh.log")" -eq 2 ]
}

@test "prefixed and nested forms are gated" {
  local command
  for command in \
    'command gh pr ready 7' \
    'GH_HOST=github.com gh pr ready 7' \
    'gh -R owner/repo pr ready 7' \
    'gh --repo=owner/repo pr ready 7' \
    'jj git push && gh pr ready 7' \
    'for n in 7; do gh pr ready 7; done' \
    '(gh pr ready 7)'; do
    gate "$command"
    [ "$(decision)" = "deny" ]
  done
}

@test "commands that do not mark a PR ready pass" {
  local command
  for command in \
    'gh pr view 7' \
    'gh pr ready --help' \
    'gh pr ready 7 --undo' \
    'echo "gh pr ready 7"' \
    "rg 'gh pr ready' docs" \
    'jj desc -m "docs: run gh pr ready; gh pr ready 7 later"' \
    '# gh pr ready 7' \
    'high pr ready 7'; do
    gate "$command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "heredoc bodies are ignored but commands after them are not" {
  gate "$(printf "cat > body.md <<'EOF'\ngh pr ready 7\ngh pr create\nEOF\necho done")"
  [ -z "$output" ]

  gate "$(printf "cat > body.md <<'EOF'\ntext\nEOF\ngh pr ready 7")"
  [ "$(decision)" = "deny" ]
}

@test "a non-draft create is denied" {
  local command
  for command in 'gh pr create --title x' 'gh pr new' 'gh pr create -t "a --draft b"'; do
    gate "$command"
    [ "$(decision)" = "deny" ]
    [[ "$(reason)" == *"--draft"* ]]
  done
}

@test "a draft create passes" {
  local command
  for command in \
    'gh pr create --draft --title x' \
    'gh pr create -d' \
    'gh pr create --title "a; b" --draft' \
    'gh pr create --help' \
    'gh pr create --dry-run'; do
    gate "$command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "backslash continuation lines stay in one command" {
  gate "$(printf 'gh pr create --title x \\\n  --draft')"
  [ -z "$output" ]

  gate "$(printf 'gh \\\n  pr ready 7')"
  [ "$(decision)" = "deny" ]

  add_run r1 7 "$HEAD_SHA" 0 passed
  gate "$(printf 'gh pr ready \\\n  7 -R owner/repo')"
  [ -z "$output" ]
  grep -q 'pr view 7 -R owner/repo --json' "$TEST_HOME/gh.log"
}

@test "a multi-line quoted body stays in one command" {
  gate "$(printf 'gh pr create --body "first\n\ngh pr ready 7\n" --draft')"
  [ -z "$output" ]
}

@test "cursor format uses permission and messages" {
  gate 'gh pr ready 7' cursor
  [ "$status" -eq 0 ]
  [ "$(jq -r '.permission' <<<"$output")" = "deny" ]
  [[ "$(jq -r '.agent_message' <<<"$output")" == *"self-review-checks"* ]]
  [[ "$(jq -r '.user_message' <<<"$output")" == *"self-review-checks"* ]]
}

@test "cursor reads a top-level command" {
  run bash -c 'printf "%s" "$1" | bash "$2" cursor' bash \
    "$(jq -n --arg cwd "$CHECKOUT" '{command: "gh pr create", cwd: $cwd}')" "$GATE"
  [ "$(jq -r '.permission' <<<"$output")" = "deny" ]
}

@test "stays silent on malformed input and unknown formats" {
  run bash -c 'printf "not json" | bash "$1" claude' bash "$GATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run bash -c 'printf "{}" | bash "$1" other' bash "$GATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
