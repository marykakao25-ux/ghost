#!/usr/bin/env bash
#
# Bash-версия scripts/agent/claim.ps1 — захват задачи по схеме A+B
# (жёсткий лок-ветка claim/* на origin + лиз-файл tasks/claims/ в main).
#
# Порядок шагов важен: сначала берётся жёсткий лок через уникальную ветку
# claim/T-XXXX (его обеспечивает сам git-сервер), только потом пишется
# человекочитаемый лиз-файл в main. При любом отказе захват снимается
# целиком, поэтому «залипших» локов не остаётся.
#
# Примеры:
#   scripts/agent/claim.sh T-0012 cline
#   scripts/agent/claim.sh --task T-0012 --owner cline
#   scripts/agent/claim.sh T-0012 cline --takeover
#   scripts/agent/claim.sh T-0012 cline --allow-untracked

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Захват задачи: лок-ветка claim/T-XXXX + лиз tasks/claims/T-XXXX.md.

Использование:
  claim.sh <T-XXXX> <owner> [--takeover] [--lease-hours N] [--allow-untracked]
  claim.sh --task <T-XXXX> --owner <имя> [...]

Параметры:
  -t, --task ID        задача, например T-0012 (обязательно)
  -o, --owner NAME     имя агента/владельца (обязательно)
      --takeover       перехватить чужой или просроченный лиз (только после
                       чтения tasks/claims/<ID>.md)
      --lease-hours N  срок лиза в часах, по умолчанию 4
      --allow-untracked
                       не считать грязным дерево, где есть только
                       неотслеживаемые файлы (редакторские конфиги)
  -h, --help           эта справка
EOF
}

main() {
	local task='' owner='' takeover=0 lease_hours="$DEFAULT_LEASE_HOURS" allow_untracked=0

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
		--takeover)
			takeover=1
			shift
			;;
		--lease-hours)
			lease_hours="${2-}"
			shift 2
			;;
		--allow-untracked)
			allow_untracked=1
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
			if [[ -z "$task" ]]; then
				task="$1"
			elif [[ -z "$owner" ]]; then
				owner="$1"
			else
				die "Лишний аргумент: $1"
			fi
			shift
			;;
		esac
	done

	[[ -n "$task" ]] || die 'Не указана задача. Пример: claim.sh T-0012 cline'
	[[ -n "$owner" ]] || die 'Не указан владелец. Пример: claim.sh T-0012 cline'
	[[ "$lease_hours" =~ ^[0-9]+$ ]] || die "Некорректный --lease-hours: '$lease_hours'"

	local task_id
	task_id="$(printf '%s' "$task" | tr '[:lower:]' '[:upper:]')"
	[[ "$task_id" =~ ^T-[0-9]{4}$ ]] || die "Некорректный id задачи '$task'. Ожидается формат T-0001."

	local claim_ref='' start_branch='' claim_file='' task_path='' branch_name=''

	cleanup_local_main() { git_run reset --hard origin/main >/dev/null 2>&1 || true; }

	drop_lock_and_die() {
		# Снимает лок-ветку (если была создана) и откатывает локальный main.
		local message="$1"
		cleanup_local_main
		if [[ -n "$claim_ref" ]]; then
			if remove_remote_ref "$claim_ref"; then
				warn "Лок $claim_ref снят."
			else
				warn "Не удалось снять $claim_ref — снимите вручную: git push origin --delete $claim_ref"
			fi
		fi
		die "$message"
	}

	# ------------------------------------------------------------ шаг 1 ----
	step '1. Синхронизация с origin и проверка рабочего дерева'
	set_git_identity_if_missing
	if ! test_clean_worktree; then
		local dirty unexpected
		dirty="$(worktree_dirty_entries)"
		if ((allow_untracked)); then
			unexpected="$(grep -v '^??' <<<"$dirty" || true)"
			if [[ -n "$unexpected" ]]; then
				die "В дереве есть изменённые файлы (не только неотслеживаемые):"$'\n'"$unexpected"$'\n'"Закоммитьте или уберите их (git status) и повторите."
			fi
			warn "В дереве есть неотслеживаемые файлы (--allow-untracked), продолжаю:"$'\n'"$dirty"
		else
			die 'Рабочее дерево грязное. Закоммитьте или уберите изменения (git status) и повторите.'$'\n'"$dirty"$'\n'"Если это только редакторские файлы, добавьте их в .gitignore или запустите с --allow-untracked."
		fi
	fi
	git_run fetch --prune origin >/dev/null

	# ------------------------------------------------------------ шаг 2 ----
	claim_ref="$(claim_branch_name "$task_id")"
	step "2. Проверка жёсткого лока $claim_ref (слой B)"
	if remote_branch_exists claim "$task_id"; then
		if ((!takeover)); then
			die "Лок $claim_ref уже существует — задачу кто-то держит."$'\n'"   Живой он или нет, покажет: git show origin/$claim_ref --stat"$'\n'"   Снять просроченный лок: scripts/agent/claim.sh $task_id $owner --takeover"
		fi
		warn "Лок $claim_ref уже есть, режим --takeover: старый лок будет снят после проверок."
	fi

	# ------------------------------------------------------------ шаг 3 ----
	step "3. Проверка рабочей ветки task/$task_id-*"
	local -a task_branches=()
	local remote_name
	while IFS= read -r remote_name; do
		[[ -n "$remote_name" ]] || continue
		[[ "$(branch_prefix "$remote_name")" == 'task' ]] || continue
		if [[ "$(branch_suffix "$remote_name")" == "$task_id"-* ]]; then
			task_branches+=("$remote_name")
		fi
	done < <(remote_branch_names '*')

	if ((${#task_branches[@]} > 0)) && ((!takeover)); then
		die "Ветка работы уже существует: ${task_branches[*]}"$'\n'"   Значит работа велась и не была закрыта. Проверьте статус задачи:"$'\n'"   scripts/agent/status.sh"$'\n'"   Если ветка брошена — запускайте с --takeover."
	fi
	if ((${#task_branches[@]} > 0)); then
		warn "Найдены ветки работы: ${task_branches[*]}. Будут переиспользованы после takeover."
	fi

	# ------------------------------------------------------------ шаг 4 ----
	step '4. Обновление main'
	start_branch="$(git_run rev-parse --abbrev-ref HEAD)"
	git_switch main >/dev/null || die 'Не удалось переключиться на main. Проверьте git status.'
	local pull_out=''
	if ! pull_out="$(git_run pull --ff-only origin main 2>&1)"; then
		die 'Не удалось обновить main (--ff-only). Возможно, локальный main разошёлся с origin.'$'\n'"$pull_out"
	fi
	ok "main = $(git_run rev-parse --short HEAD)"
	initialize_task_system

	# ------------------------------------------------------------ шаг 5 ----
	step "5. Разбор задачи $task_id и проверка лиза (слой A)"
	task_path="$(find_task "$task_id")"
	local task_status
	task_status="$(task_field "$task_path" status)"
	local -a task_paths=()
	mapfile -t task_paths < <(task_list "$task_path" paths)

	[[ "$task_status" == 'done' ]] && die "Задача $task_id уже закрыта (status: done). Возьмите другую."
	((${#task_paths[@]} > 0)) || die "В задаче $task_id не задано поле paths — нечем защищаться от конфликтов."

	claim_file="$CLAIMS_DIR/$task_id.md"
	if [[ -f "$claim_file" ]]; then
		local claim_owner
		claim_owner="$(task_field "$claim_file" owner)"
		if ! lease_expired "$claim_file"; then
			if ((!takeover)); then
				die "Задача $task_id уже занята: owner=$claim_owner, осталось $(lease_remaining "$claim_file")."$'\n'"   Если владелец пропал: --takeover (только после проверки tasks/claims/$task_id.md)."
			fi
			warn "Перехват ЖИВОГО лиза: owner=$claim_owner, осталось $(lease_remaining "$claim_file")."
		else
			warn "Лиз задачи $task_id просрочен (owner=$claim_owner) — перехватываем."
		fi
	fi

	# ------------------------------------------------------------ шаг 6 ----
	step '6. Проверка пересечения путей с активными задачами'
	local conflicts
	conflicts="$(path_conflicts "$task_id" -- "${task_paths[@]}")"
	if [[ -n "$conflicts" ]]; then
		die "Задача $task_id пересекается по файлам с уже занятыми задачами:"$'\n'"$conflicts"$'\n'"   Возьмите другую задачу или дождитесь освобождения этих файлов."
	fi
	local pretty_paths=''
	local path
	for path in "${task_paths[@]}"; do pretty_paths+="'$path', "; done
	ok "Пересечений нет: ${pretty_paths%, }"

	# ------------------------------------------------------ шаг 7.5: лок B ----
	if remote_branch_exists claim "$task_id"; then
		step "7.5. Перехват существующего лока $claim_ref"
		if remove_remote_ref "$claim_ref"; then
			ok "Лок $claim_ref снят."
		else
			warn "Не удалось снять $claim_ref — снимите вручную: git push origin --delete $claim_ref"
		fi
	fi

	step "7.5. Захват жёсткого лока: push $claim_ref"
	git_run commit --allow-empty -m "[$task_id] claim lock: $owner" >/dev/null
	local lock_out=''
	if ! lock_out="$(git_run push origin "HEAD:refs/heads/$claim_ref" 2>&1)"; then
		cleanup_local_main
		if [[ "$lock_out" =~ (already\ exists|fetch\ first|non-fast-forward|rejected) ]]; then
			die "Лок $claim_ref перехватил другой агент (гонка). Задача занята — возьмите другую."$'\n'"$lock_out"
		fi
		die "Не удалось создать лок-ветку (нет прав на push?). Захват отменён, ничего не изменено."$'\n'"$lock_out"
	fi
	ok "Лок $claim_ref закреплён за $owner."

	# -------------------------------------------------------- шаг 8: лиз A ----
	step '8. Запись лиз-файла в main (слой A)'
	local lease_until now_epoch
	now_epoch="$(date -u +%s)"
	lease_until="$(format_lease_time $((now_epoch + lease_hours * 3600)))"

	local task_slug
	task_slug="$(basename "$task_path" .md)"
	task_slug="${task_slug#"$task_id"-}"
	branch_name="task/$task_id-$task_slug"

	write_claim_files() {
		# Лиз-файл + обновление статуса задачи. Вызывается повторно после rebase.
		local paths_yaml='' p
		for p in "${task_paths[@]}"; do paths_yaml+="  - $p"$'\n'; done
		mkdir -p "$CLAIMS_DIR"
		{
			printf -- '---\n'
			printf 'id: %s\n' "$task_id"
			printf 'title: %s\n' "$(task_field "$task_path" title)"
			printf 'status: claimed\n'
			printf 'owner: %s\n' "$owner"
			printf 'lease_until: %s\n' "$lease_until"
			printf 'branch: %s\n' "$branch_name"
			printf 'claimed_paths:\n%s' "$paths_yaml"
			printf 'lock_ref: %s\n' "$claim_ref"
			printf -- '---\n\n'
			printf '# Лиз задачи %s\n\n' "$task_id"
			printf 'Файл создан автоматически `scripts/agent/claim.sh`. Не редактировать руками.\n'
			printf 'Снимается командой `scripts/agent/release.ps1` (или `release.sh`).\n'
		} >"$claim_file"

		set_task_field "$task_path" status 'claimed'
		set_task_field "$task_path" owner "$owner"
		set_task_field "$task_path" lease_until "$lease_until"
		set_task_field "$task_path" branch "$branch_name"
	}

	write_claim_files
	git_run add -- "tasks/claims/$task_id.md" "tasks/$(basename "$task_path")"

	# Проверка «а вдруг кто-то успел» прямо перед коммитом.
	local staged foreign
	staged="$(git_run diff --cached --name-only)"
	foreign="$(grep -v -e '^tasks/' -e '^$' <<<"$staged" || true)"
	if [[ -n "$foreign" ]]; then
		drop_lock_and_die "В индексе оказались посторонние файлы: $(tr '\n' ',' <<<"$foreign" | sed 's/,$//' | tr ',' ' '). Лок снят, захват отменён."
	fi

	git_run commit -m "[$task_id] chore(claim): acquire by $owner" >/dev/null

	local main_push_out=''
	if ! main_push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
		warn 'Push в main отвергнут (кто-то успел раньше) — rebase и повторная проверка конфликтов.'
		if ! git_run pull --rebase origin main >/dev/null 2>&1; then
			git_run rebase --abort >/dev/null 2>&1 || true
			drop_lock_and_die "Не удалось совместить лиз с новым main. Лок $claim_ref снят, захват отменён."
		fi

		# Повторная проверка ПОСЛЕ rebase: именно здесь ловится чужой лиз задачи
		# и чужой захват тех же файлов.
		if [[ -f "$claim_file" ]]; then
			local rival_owner
			rival_owner="$(task_field "$claim_file" owner)"
			if [[ "$rival_owner" != "$owner" ]] && ! lease_expired "$claim_file"; then
				drop_lock_and_die "Задачу $task_id одновременно взял $rival_owner. Лок снят, вы проиграли гонку — берите другую задачу."
			fi
		fi
		local late_conflicts
		late_conflicts="$(path_conflicts "$task_id" -- "${task_paths[@]}")"
		if [[ -n "$late_conflicts" ]]; then
			drop_lock_and_die "После обновления main появились пересечения файлов:"$'\n'"$late_conflicts"$'\n'"Лок $claim_ref снят."
		fi

		if ! main_push_out="$(git_run push origin HEAD:refs/heads/main 2>&1)"; then
			drop_lock_and_die "Не удалось записать лиз в main (нет прав на push?). Лок $claim_ref снят."$'\n'"$main_push_out"
		fi
	fi
	ok "Лиз tasks/claims/$task_id.md опубликован в main."

	# ------------------------------------------------------------ шаг 9 ----
	step "9. Создание ветки работы $branch_name"
	if ! git_switch -c "$branch_name" --track origin/main >/dev/null; then
		git_switch "$branch_name" >/dev/null || die "Не удалось создать или переключиться на ветку $branch_name."
	fi
	local branch_push_out=''
	if ! branch_push_out="$(git_run push -u origin "$branch_name" 2>&1)"; then
		die "Не удалось запушить ветку $branch_name (нет прав на push?)."$'\n'"$branch_push_out"
	fi
	ok "Ветка $branch_name создана и запушена."

	if [[ "$start_branch" != 'main' && "$start_branch" != "$branch_name" ]]; then
		warn "До захвата вы были на ветке '$start_branch' — вернитесь к ней вручную, если нужно."
	fi

	printf '\n'
	ok "Задача $task_id принадлежит вам ($owner) до $lease_until."
	printf 'Следующие шаги:\n'
	printf "  1. Работайте только в '%s' и только с файлами: %s\n" "$branch_name" "${task_paths[*]}"
	printf '  2. Продление лока: scripts/agent/heartbeat.sh --task %s --owner %s  (или heartbeat.ps1)\n' "$task_id" "$owner"
	printf '  3. Завершение:     scripts/agent/release.sh   --task %s --owner %s  (или release.ps1)\n' "$task_id" "$owner"
	printf '  4. PR -> squash merge -> ветка task/* удаляется автоматически.\n'
}

main "$@"
