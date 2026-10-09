#!/usr/bin/env bash
set -euo pipefail
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CDPATH= cd -- "$script_dir/.."
command -v docker >/dev/null 2>&1 || {
  printf '%s\n' 'Required program not found: docker' >&2
  exit 127
}
mkdir -p build/static
case "${1:-}" in
  prepare)
    docker pull --platform linux/amd64 crystallang/crystal:1.21.1-alpine
    base="$(docker image inspect crystallang/crystal:1.21.1-alpine \
      --format '{{index .RepoDigests 0}}')"
    [[ "$base" == *@sha256:* ]] || {
      printf '%s\n' 'An immutable base-image digest could not be resolved.' >&2
      exit 1
    }
    docker build --platform linux/amd64 --build-arg "JEDI_BASE_IMAGE=$base" \
      -f release/Dockerfile -t jedi-builder:1.0.0 .
    docker image inspect jedi-builder:1.0.0 --format '{{.Id}}' > build/static/builder-id.txt
    printf '%s\n' "$base" > build/static/base-image.txt
    printf '%s\n' 'Builder prepared. Preserve this image for reproducible rebuilds.'
    ;;
  build)
    [[ -s build/static/builder-id.txt ]] || {
      printf '%s\n' 'First run: bash release/build-static.sh prepare' >&2
      exit 1
    }
    image_id="$(< build/static/builder-id.txt)"
    [[ "$image_id" =~ ^sha256:[a-f0-9]{64}$ ]] || exit 1
    commit="unknown"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      commit="$(git rev-parse HEAD)"
      [[ -z "$(git status --porcelain --untracked-files=normal)" ]] || {
        printf '%s\n' 'Commit the reviewed source files before making a release build.' >&2
        exit 1
      }
    fi
    docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
      --env SHARDS_CACHE_PATH=/tmp/jedi-shards-cache \
      --env CRYSTAL_CACHE_DIR=/tmp/jedi-crystal-cache \
      --env TZ=UTC --env LANG=C.UTF-8 --env "JEDI_GIT_COMMIT=$commit" \
      --mount "type=bind,source=$PWD,target=/workspace" --workdir /workspace \
      "$image_id" bash release/build-in-container.sh
    printf '%s\n' 'Static binary ready: build/static/jedi' \
      'Next: run the smoke test on the target Linux or WSL2 machine.'
    ;;
  *)
    printf '%s\n' 'Usage: bash release/build-static.sh prepare|build' >&2
    exit 2
    ;;
esac
