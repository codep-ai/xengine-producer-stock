#!/bin/bash
# xdbt — run dbt for THIS project with a clean flag environment (.env.dev exports DBT_PROFILE/DBT_TARGET which override the project's profile).
set -a; source /home/ec2-user/.env.dev; set +a
unset DBT_PROFILE DBT_TARGET DBT_PROJECT_PATH DBT_PROJECT_DIR
# Athena = dbt v1 only; the Athena profiles live in the v1-only dir (split 2026-10-13)
export DBT_PROFILES_DIR=/home/ec2-user/.dbt/athena AWS_DEFAULT_REGION=ap-southeast-2
cd /home/ec2-user/git/xengine-producer-stock && exec /home/ec2-user/venv_ai_etl/bin/dbt "$@"
