#!/usr/bin/env bash
# Create a local virtualenv and install Python dependencies (Strands 1.57+).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT}/src"

cd "${APP_DIR}"
python3 -m venv .venv
.venv/bin/pip install -U pip
.venv/bin/pip install -r requirements.txt

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — fill in KB IDs / runtime values as you deploy."
fi

echo "Setup complete. Activate with: source src/.venv/bin/activate"
.venv/bin/python -c "from importlib.metadata import version; print('strands-agents', version('strands-agents'))"
