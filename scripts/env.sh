#!/usr/bin/env bash
# 測ったときの版を、macOS でも Linux でも同じ形で残す。
set -euo pipefail
printf 'mise\t%s\n' "$(mise --version | head -1)"
printf 'os\t%s %s\n' "$(uname -s)" "$(uname -m)"
printf 'shell\t%s\n' "${SHELL:-unknown}"
printf 'date\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
