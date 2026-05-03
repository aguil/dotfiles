set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just -f "{{ justfile_directory() }}/qa.just" --list

# Lint shell scripts and test files.
lint-shell:
  @set -euo pipefail; \
  fmt_files=("{{ justfile_directory() }}/scripts/bookmark-pr-hygiene.sh" "{{ justfile_directory() }}/scripts/repos-smoke.sh"); \
  while IFS= read -r _file; do fmt_files+=("$_file"); done < <(find "{{ justfile_directory() }}/tests/shell" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.bats' \) 2>/dev/null | sort); \
  mise exec -- shfmt -d -i 2 -ci "${fmt_files[@]}"; \
  sc_files=("{{ justfile_directory() }}/scripts/bookmark-pr-hygiene.sh" "{{ justfile_directory() }}/scripts/repos-smoke.sh"); \
  while IFS= read -r _file; do sc_files+=("$_file"); done < <(find "{{ justfile_directory() }}/tests/shell" -type f \( -name '*.sh' -o -name '*.bash' \) 2>/dev/null | sort); \
  mise exec -- shellcheck "${sc_files[@]}"

# Run deterministic shell unit tests.
test-shell-unit:
  @mise exec -- bats "{{ justfile_directory() }}/tests/shell/unit"

# Run black-box integration shell tests.
test-shell-integration:
  @mise exec -- bats "{{ justfile_directory() }}/tests/shell/integration"

# Run lightweight smoke checks for public just command contracts.
smoke-shell:
  @set -euo pipefail; \
  projects_root="${DEV_ROOT:-$HOME/dev}/projects"; \
  if [ -d "$projects_root" ] && bash "{{ justfile_directory() }}/scripts/proj-list-projects.sh" "$projects_root" | IFS= read -r _first; then \
    if [ -n "${_first:-}" ]; then bash "{{ justfile_directory() }}/scripts/proj-smoke.sh"; else printf 'smoke-shell: skipping proj-smoke (no projects under %s)\n' "$projects_root"; fi; \
  else \
    printf 'smoke-shell: skipping proj-smoke (projects root missing: %s)\n' "$projects_root"; \
  fi; \
  bash "{{ justfile_directory() }}/scripts/repos-smoke.sh"

# Full shell verification suite.
verify-shell: lint-shell test-shell-unit test-shell-integration smoke-shell
