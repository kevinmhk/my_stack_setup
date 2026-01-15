#!/usr/bin/env bash
set -euo pipefail

run() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  "$@"
}

run gemini extensions install https://github.com/upstash/context7
run gemini extensions install https://github.com/github/github-mcp-server
run gemini extensions install https://github.com/gemini-cli-extensions/conductor
run gemini extensions install https://github.com/gemini-cli-extensions/nanobanana
run gemini extensions install https://github.com/gemini-cli-extensions/flutter
run gemini extensions install https://github.com/gemini-cli-extensions/security
run gemini extensions install https://github.com/gemini-cli-extensions/code-review
run gemini extensions install https://github.com/gemini-cli-extensions/firebase
run gemini extensions install https://github.com/firebase/snippets-rules
run gemini extensions install https://github.com/gemini-cli-extensions/firestore-native
