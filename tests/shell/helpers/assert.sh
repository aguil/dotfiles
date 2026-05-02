#!/usr/bin/env bash

assert_status() {
  local expected="$1"
  local actual="$2"
  if [ "$actual" -ne "$expected" ]; then
    printf 'assert_status: expected %s, got %s\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *)
      printf 'assert_contains: expected to find [%s]\n' "$needle" >&2
      return 1
      ;;
  esac
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*)
      printf 'assert_not_contains: did not expect [%s]\n' "$needle" >&2
      return 1
      ;;
    *) return 0 ;;
  esac
}
