set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod proj

# List recipes (default task).
default:
  @just --list
