#!/bin/bash
set -euo pipefail

tool_dir="$(cd "$(dirname "$0")" && pwd)"
"$tool_dir/build.sh"
open -n "$tool_dir/dist/Material Recipe Viewer.app" --args "$@"
