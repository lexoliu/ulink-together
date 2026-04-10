#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

cargo run -p together-server --bin demo_seed -- \
  --database-url "${DEMO_DATABASE_URL:-sqlite://./together-demo.db}" \
  --teacher-count "${DEMO_TEACHER_COUNT:-4}" \
  --student-count "${DEMO_STUDENT_COUNT:-72}" \
  --activities-per-teacher "${DEMO_ACTIVITIES_PER_TEACHER:-6}" \
  --comments-per-activity "${DEMO_COMMENTS_PER_ACTIVITY:-4}" \
  --messages-per-activity "${DEMO_MESSAGES_PER_ACTIVITY:-8}" \
  --admin-password "${DEMO_ADMIN_PASSWORD:-DemoAdmin123!}" \
  --teacher-password "${DEMO_TEACHER_PASSWORD:-DemoTeacher123!}" \
  --student-password "${DEMO_STUDENT_PASSWORD:-DemoStudent123!}" \
  --seed "${DEMO_SEED:-20260317}" \
  --reset
