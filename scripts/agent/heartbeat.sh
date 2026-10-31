#!/usr/bin/env bash
#
# Bash-версия scripts/agent/heartbeat.ps1 — продление лока задачи.
#
# Обновляет lease_until в tasks/claims/T-XXXX.md и tasks/T-XXXX-*.md
# и пушит это в main. Запускать раз в 1–2 часа во время долгой работы.
#
#   scripts/agent/heartbeat.sh --task T-0012 --owner cline
#   scripts/agent/heartbeat.sh --task T-0012 --owner cline --lease-hours 6

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Продление лока (heartbeat): lease_until в лизе и в задаче, push в main.

Использование:
  heartbeat.sh --task <T-XXXX> --owner <имя> [--lease-hours N]

Параметры:
  -t, --task ID        задача (обязательно)
  -o, --owner NAME     владелец лиза (обязательно)
      --lease-hours N  сколько часов добавить, по умолчанию 4
  -h, --help           эта справка
EOF
}

main() {
	local task='' owner='' lease_hours="$DEFAULT_LEASE_HOURS"

	while (($#)); do
		case "$1" in
		-t | --task)
			task="${2-}"
			shift 2
			;;
		-o | --owner)
			owner="${2-}"
			shift 2
			;;
		--lease-hours)
			lease_hours="${2-}"
			shift 2
			;;
		-h | --help)
			usage
			return 0
			;;
		-*)
			die "Неизвестный параметр: $1 (см. --help)"
			;;
		*)
			if [[ -z "$task" ]]; then task="$1"; else die "Лишний аргумент: $1"; fi
			shift
			;;
		esac
	done

	[[ -n "$task" ]] || die 'Не указана задача. Пример: heartbeat.sh --task T-0012 --owner cline'
	[[ -n "$owner" ]] || die 'Не указан владелец.'
	[[ "$lease_hours" =~ ^[0-9]+$ ]] || die "Некорректный --lease-hours: '$lease_hours'"

	local task_id
	task_id="$(printf '%s' "$task" | tr '[:lower:]' '[:upper:]')"

	initialize_task_system

	test_clean_worktree || die 'Рабочее дерево грязное — сначала закоммитьте изменения.'
	git_switch main >/dev/null || die 'Не удалось переключиться на main.'
	local pull_out=''
	if ! pull_out="$(git_run pull --ff-only origin main 2>&1)"; then
		die 'Не удалось обновить main (--ff-only).'$'\n'"$pull_out"
	fi

	local task_path claim_file claim_owner lease
	task_path="$(find_task "$task_id")"
	claim_file="$CLAIMS_DIR/$task_id.md"
	[[ -f "$claim_file" ]] || die "Лиз tasks/claims/$task_id.md отсутствует — задача не взята."

	claim_owner="$(task_field "$claim_file" owner)"
	[[ "$claim_owner" == "$owner" ]] || die "Лиз принадлежит '$claim_owner', а не '$owner'."

	lease="$(format_lease_time $(($(date -u +%s) + lease_hours * 3600)))"
	set_task_field "$claim_file" lease_until "$lease"
	set_task_field "$task_path" lease_until "$lease"
	git_run add -- "tasks/claims/$task_id.md" "tasks/$(basename "$task_path")"
	git_run commit -m "[$task_id] chore(claim): heartbeat $owner" >/dev/null

	local push_out=''
	if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
		git_run pull --rebase origin main >/dev/null 2>&1 || true
		if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
			die "Не удалось обновить лиз в main."$'\n'"$push_out"
		fi
	fi

	ok "Лиз $task_id продлён до $lease."
}

main "$@"
