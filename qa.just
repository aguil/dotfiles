set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just -f "{{ justfile_directory() }}/qa.just" --list

# Lint shell scripts and test files.
lint-shell:
  @set -euo pipefail; \
  fmt_files=("{{ justfile_directory() }}/dot_local/bin/executable_paste-image-agent.sh" "{{ justfile_directory() }}/dot_local/bin/executable_wl-paste" "{{ justfile_directory() }}/dot_local/bin/executable_ai-statusline" "{{ justfile_directory() }}/dot_local/bin/lib/ai-context-thresholds.sh" "{{ justfile_directory() }}/dot_claude/hooks/executable_context-threshold-stop.sh" "{{ justfile_directory() }}/dot_claude/modify_settings.json.tmpl" "{{ justfile_directory() }}/.chezmoiscripts/run_after_25-cursor-statusline.sh" "{{ justfile_directory() }}/scripts/bookmark-pr-hygiene.sh" "{{ justfile_directory() }}/scripts/repos-smoke.sh"); \
  while IFS= read -r _file; do fmt_files+=("$_file"); done < <(find "{{ justfile_directory() }}/tests/shell" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.bats' \) 2>/dev/null | sort); \
  mise exec --locked -- shfmt -d -i 2 -ci "${fmt_files[@]}"; \
  sc_files=("{{ justfile_directory() }}/dot_local/bin/executable_paste-image-agent.sh" "{{ justfile_directory() }}/dot_local/bin/executable_wl-paste" "{{ justfile_directory() }}/dot_local/bin/lib/clipboard-image.sh" "{{ justfile_directory() }}/dot_local/bin/executable_ai-statusline" "{{ justfile_directory() }}/dot_local/bin/lib/ai-context-thresholds.sh" "{{ justfile_directory() }}/dot_claude/hooks/executable_context-threshold-stop.sh" "{{ justfile_directory() }}/dot_claude/modify_settings.json.tmpl" "{{ justfile_directory() }}/.chezmoiscripts/run_after_25-cursor-statusline.sh" "{{ justfile_directory() }}/scripts/bookmark-pr-hygiene.sh" "{{ justfile_directory() }}/scripts/repos-smoke.sh"); \
  while IFS= read -r _file; do sc_files+=("$_file"); done < <(find "{{ justfile_directory() }}/tests/shell" -type f \( -name '*.sh' -o -name '*.bash' \) 2>/dev/null | sort); \
  mise exec --locked -- shellcheck "${sc_files[@]}"

# Check Neovim Lua formatting.
lint-nvim-lua:
  @mise exec --locked -- stylua --check --config-path "{{ justfile_directory() }}/dot_config/nvim/dot_stylua.toml" "{{ justfile_directory() }}/dot_config/nvim" "{{ justfile_directory() }}/tests/nvim"

# Run Neovim Lua module-load smoke checks.
smoke-nvim-lua:
  @mise exec --locked -- nvim --headless --clean -u NONE -l "{{ justfile_directory() }}/tests/nvim/smoke.lua"

# Run focused Neovim Lua unit tests.
test-nvim-lua:
  @mise exec --locked -- nvim --headless --clean -u NONE -l "{{ justfile_directory() }}/tests/nvim/run_tests.lua"

# Run deterministic shell unit tests.
test-shell-unit:
  @mise exec --locked -- bats "{{ justfile_directory() }}/tests/shell/unit"

# Run black-box integration shell tests.
test-shell-integration:
  @mise exec --locked -- bats "{{ justfile_directory() }}/tests/shell/integration"

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

# Full Neovim Lua verification suite.
verify-nvim-lua: lint-nvim-lua smoke-nvim-lua test-nvim-lua
