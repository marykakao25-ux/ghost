#!/usr/bin/env bash
#
# Bash-версия scripts/agent/release.ps1 — закрытие задачи:
# перенос в tasks/done/, снятие лиза и лок-ветки claim/*.
#
# Порядок критичен: сначала работа коммитится и пушится в task/*, и только
# потом снимается лок claim/*. Снять лок раньше — значит дать другому агенту
# взять задачу, пока работа ещё не сохранена на сервере.
#
# Примеры:
#   scripts/agent/release.sh --task T-0012 --owner cline
#   scripts/agent/release.sh --task T-0002,T-0004 --owner cline
#   scripts/agent/release.sh --task T-0012 --owner cline --abort

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Закрытие задачи: статус done, перенос в tasks/done/, снятие лиза и claim/*.

Использование:
  release.sh --task <T-XXXX[,T-YYYY]> --owner <имя> [--abort]

Параметры:
  -t, --task ID        задача (можно несколько через запятую)
  -o, --owner NAME     владелец лиза (обязательно)
      --abort          закрыть как «отменена»: status=blocked, работа не вливается
  -h, --help           эта справка
EOF
}

release_one() {
	local task_id="$1" owner="$2" abort="$3"
	local task_path='' claim_file='' claim_owner='' branch_name='' claimed_lock=''
	local claim_ref='' local_branch='' return_branch='' done_name=''

	step "1. Чтение задачи $task_id"
	task_path="$(find_task "$task_id")"
	claim_file="$CLAIMS_DIR/$task_id.md"

	[[ -f "$claim_file" ]] || die "Нет лиз-файла tasks/claims/$task_id.md — задачу никто не держал (или лиз уже снят)."

	claim_owner="$(task_field "$claim_file" owner)"
	branch_name="$(task_field "$claim_file" branch)"
	claimed_lock="$(task_field "$claim_file" lock_ref)"
	if [[ -n "$claimed_lock" ]]; then claim_ref="$claimed_lock"; else claim_ref="$(claim_branch_name "$task_id")"; fi

	[[ "$claim_owner" == "$owner" ]] ||
		die "Лиз принадлежит '$claim_owner', а вы '$owner'. Задачу закрывает только владелец (или force-release.sh)."

	step "2. Проверка, что работа сохранена в ветке $branch_name"
	local_branch="$(git_run rev-parse --abbrev-ref HEAD)"
	test_clean_worktree || die 'Рабочее дерево грязное: закоммитьте изменения перед закрытием задачи.'

	if ((!abort)); then
		remote_branch_exists task "$(branch_suffix "$branch_name")" ||
			die "Ветка работы $branch_name не существует на origin. Запушьте работу: git push -u origin $branch_name"
		if [[ "$local_branch" == "$branch_name" ]]; then
			local ahead
			ahead="$(git_run rev-list --count "origin/$branch_name..HEAD" 2>/dev/null || echo 0)"
			((ahead == 0)) || die "В $branch_name есть незапушенные коммиты ($ahead). Сначала git push."
		fi
	fi

	step '3. Обновление main и перенос задачи в tasks/done/'
	if [[ "$local_branch" == task/* ]]; then return_branch="$local_branch"; else return_branch='main'; fi
	git_switch main >/dev/null || die 'Не удалось переключиться на main.'
	local pull_out=''
	if ! pull_out="$(git_run pull --ff-only origin main 2>&1)"; then
		die 'Не удалось обновить main (--ff-only).'$'\n'"$pull_out"
	fi

	mkdir -p "$DONE_DIR"
	done_name="$(basename "$task_path")"

	if ((abort)); then
		set_task_field "$task_path" status 'blocked'
		add_task_note "$task_path" "задача снята владельцем $owner (работа не вливается), ветка $branch_name"
	else
		set_task_field "$task_path" status 'done'
		add_task_note "$task_path" "работа завершена владельцем $owner, ветка $branch_name, ожидает PR"
	fi

	git_run add -- "tasks/$done_name"
	git_run mv -f "tasks/$done_name" "tasks/done/$done_name"
	git_run rm --quiet --ignore-unmatch -- "tasks/claims/$task_id.md"

	step '4. Коммит и push в main'
	git_run commit -m "[$task_id] chore: release ($owner)" >/dev/null

	local push_out=''
	if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
		git_run pull --rebase origin main >/dev/null 2>&1 || true
		if ! push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
			die "Не удалось записать релиз в main. Лок НЕ снят — повторите release.sh."$'\n'"$push_out"
		fi
	fi
	ok 'Лиз снят, задача перенесена в tasks/done/.'

	step "5. Снятие лок-ветки $claim_ref"
	if remove_remote_ref "$claim_ref"; then
		ok "$claim_ref удалён."
	else
		warn "$claim_ref не удалён (уже нет или нет прав)."
	fi

	if ((abort)); then
		git_switch main >/dev/null || true
		printf '\n'
		ok "Задача $task_id закрыта как отменённая. Ветка $branch_name осталась в origin — удалите вручную при необходимости."
		return 0
	fi

	git_switch "$return_branch" >/dev/null || true
	printf '\n'
	ok 'Готово. Осталось открыть PR и влить squash-merge:'
	printf '  ветка:  %s\n' "$branch_name"
	printf '  задача: %s\n' "$task_id"
	printf '  В названии PR обязательно укажите [T-XXXX]: это проверяет workflow agent-guard.yml.\n'
}

main() {
	local -a tasks=()
	local -a parts=()
	local owner='' abort=0 part

	while (($#)); do
		case "$1" in
		-t | --task)
			IFS=',' read -r -a parts <<<"${2-}"
			for part in "${parts[@]}"; do
				part="$(trim "$part")"
				[[ -n "$part" ]] && tasks+=("$(printf '%s' "$part" | tr '[:lower:]' '[:upper:]')")
			done
			shift 2
			;;
		-o | --owner)
			owner="${2-}"
			shift 2
			;;
		--abort)
			abort=1
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
			IFS=',' read -r -a parts <<<"$1"
			for part in "${parts[@]}"; do
				part="$(trim "$part")"
				[[ -n "$part" ]] && tasks+=("$(printf '%s' "$part" | tr '[:lower:]' '[:upper:]')")
			done
			shift
			;;
		esac
	done

	((${#tasks[@]} > 0)) || die 'Не указано ни одного id задачи.'
	[[ -n "$owner" ]] || die 'Не указан владелец. Пример: release.sh --task T-0012 --owner cline'

	initialize_task_system

	if ((${#tasks[@]} == 1)); then
		release_one "${tasks[0]}" "$owner" "$abort"
		return 0
	fi

	# Несколько задач закрываются по очереди: так проще проверить каждую и не смешать коммиты.
	local one
	for one in "${tasks[@]}"; do
		step "Закрытие $one"
		release_one "$one" "$owner" "$abort" || die "Задача $one не закрыта. Остальные не тронуты."
	done
}

main "$@"
