#!/usr/bin/env bash
#
# Bash-версия scripts/agent/force-release.ps1 — аварийное снятие зависшего лока
# (claim/*, tasks/claims/*.md), без записи результата работы.
#
# Нужен, когда агент упал и не выполнил release.sh. Перед запуском убедитесь,
# что работа не потеряется: git log origin/task/T-XXXX-*, или закройте задачу
# через release.sh --abort.
#
#   scripts/agent/force-release.sh --task T-0012 --reason "агент упал, работы нет"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Принудительное снятие лока задачи: лиз, claim/* и (опционально) task/*.

Использование:
  force-release.sh --task <T-XXXX> --reason "<почему>" [--keep-task-branch]

Параметры:
  -t, --task ID          задача (обязательно)
  -r, --reason TEXT      причина (обязательно, попадает в историю задачи)
      --keep-task-branch не удалять ветку task/T-XXXX-*
  -h, --help             эта справка
EOF
}

main() {
	local task='' reason='' keep_task_branch=0

	while (($#)); do
		case "$1" in
		-t | --task)
			task="${2-}"
			shift 2
			;;
		-r | --reason)
			reason="${2-}"
			shift 2
			;;
		--keep-task-branch)
			keep_task_branch=1
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		-*)
			die "Неизвестный параметр: $1 (см. --help)"
			;;
		*)
			die "Лишний аргумент: $1 (см. --help)"
			;;
		esac
	done

	[[ -n "$task" ]] || die 'Не указана задача.'
	[[ -n "$reason" ]] || die 'Не указана причина (--reason).'

	local task_id
	task_id="$(printf '%s' "$task" | tr '[:lower:]' '[:upper:]')"
	[[ "$task_id" =~ ^T-[0-9]{4}$ ]] || die "Некорректный id задачи '$task'."

	initialize_task_system
	warn "Принудительное снятие лока задачи $task_id. Причина: $reason"

	if ! test_clean_worktree; then
		err 'Рабочее дерево грязное — принудительное снятие отменено.'
		return 1
	fi

	git_switch main >/dev/null || die 'Не удалось переключиться на main.'
	local pull_out=''
	if ! pull_out="$(git_run pull --ff-only origin main 2>&1)"; then
		die 'Не удалось обновить main (--ff-only).'$'\n'"$pull_out"
	fi

	local task_path=''
	if ! task_path="$(try_find_task "$task_id")"; then
		# Задача уже закрыта (лежит в tasks/done/): остаётся только снять локи.
		task_path=''
		warn "Задача $task_id не найдена в tasks/ — снимаю только локи."
	fi

	local claim_file="$CLAIMS_DIR/$task_id.md"
	local owner='(none)'
	if [[ -f "$claim_file" ]]; then
		owner="$(task_field "$claim_file" owner)"
		git_run rm --quiet -- "tasks/claims/$task_id.md" >/dev/null
	fi

	if [[ -n "$task_path" ]]; then
		set_task_field "$task_path" status 'todo'
		set_task_field "$task_path" owner 'null'
		set_task_field "$task_path" lease_until 'null'
		set_task_field "$task_path" branch 'null'
		add_task_note "$task_path" "лок снят принудительно (был owner=$owner): $reason"
		git_run add -- "tasks/$(basename "$task_path")"
		git_run commit -m "[$task_id] chore(claim): force-release ($reason)" >/dev/null

		local push_out=''
		if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
			git_run pull --rebase origin main >/dev/null 2>&1 || true
			if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
				err "Не удалось обновить main; лок claim/$task_id НЕ снят."$'\n'"$push_out"
				return 1
			fi
		fi
		ok 'Лиз-файл снят, задача вернулась в todo.'
	else
		warn "Лиз-файла для $task_id нет — снимаю только ветки."
	fi

	local claim_ref
	claim_ref="$(claim_branch_name "$task_id")"
	if remove_remote_ref "$claim_ref"; then
		ok "$claim_ref удалён."
	else
		warn "$claim_ref уже отсутствовал."
	fi

	if ((!keep_task_branch)); then
		local name
		while IFS= read -r name; do
			[[ -n "$name" ]] || continue
			[[ "$(branch_prefix "$name")" == 'task' ]] || continue
			[[ "$(branch_suffix "$name")" == "$task_id"-* ]] || continue
			if remove_remote_ref "$name"; then
				ok "Ветка $name удалена (незамерженные коммиты остались в reflog сервера)."
			else
				warn "Не удалось удалить $name."
			fi
		done < <(remote_branch_names '*')
	fi
}

main "$@"
