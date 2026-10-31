#!/usr/bin/env bash
#
# Bash-версия scripts/agent/status.ps1 — таблица состояния задач: кто что держит,
# сколько живёт лок, где расходятся слои A (tasks/claims) и B (claim/* на origin).
#
# Код возврата 1 — если найдены расхождения, требующие внимания.
#
#   scripts/agent/status.sh
#   scripts/agent/status.sh --no-remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Таблица состояния задач и локов.

Использование:
  status.sh [--no-remote]

Параметры:
      --no-remote  не обращаться к origin (только локальные tasks/)
  -h, --help       эта справка
EOF
}

collect_tasks() {
	# «путь<TAB>каталог» для задач из tasks/ и tasks/done/, по алфавиту.
	local f
	{
		for f in "$TASKS_DIR"/T-*.md; do [[ -e "$f" ]] && printf '%s\ttasks\n' "$f"; done
		for f in "$DONE_DIR"/T-*.md; do [[ -e "$f" ]] && printf '%s\tdone\n' "$f"; done
	} | sort
}

main() {
	local no_remote=0

	while (($#)); do
		case "$1" in
		--no-remote)
			no_remote=1
			shift
			;;
		-h | --help)
			usage
			return 0
			;;
		*) die "Неизвестный параметр: $1 (см. --help)" ;;
		esac
	done

	initialize_task_system

	local -a r_id=() r_status=() r_dir=() r_owner=() r_ttl=() r_lock=() r_branch=() r_overlap=()
	local -a problems=()

	declare -A claim_by_id=()
	local cf cid
	while IFS= read -r cf; do
		[[ -n "$cf" ]] || continue
		cid="$(task_field "$cf" id)"
		[[ -n "$cid" ]] && claim_by_id["$cid"]="$cf"
	done < <(active_claims)

	local -a remote_claim_ids=() remote_task_branches=()
	if ((!no_remote)); then
		git_run fetch --prune origin >/dev/null 2>&1 || true
		local name
		while IFS= read -r name; do
			[[ -n "$name" ]] || continue
			if [[ "$(branch_prefix "$name")" == 'claim' ]]; then
				remote_claim_ids+=("$(branch_suffix "$name")")
			elif [[ "$(branch_prefix "$name")" == 'task' ]]; then
				remote_task_branches+=("$name")
			fi
		done < <(remote_branch_names '*')
	fi

	local file dir id status owner ttl lock_state work branch overlap claim_path
	local -a own_paths=()
	while IFS=$'\t' read -r file dir; do
		[[ -n "$file" ]] || continue
		id="$(task_field "$file" id)"
		if [[ -z "$id" ]]; then
			id="$(basename "$file" | cut -d- -f1-2)"
		fi

		local claim_file="${claim_by_id[$id]:-}"
		status="$(task_field "$file" status)"
		owner="$(task_field "$file" owner)"
		if [[ -z "$status" ]]; then
			if [[ -n "$claim_file" ]]; then status='claimed'; else status='todo'; fi
		fi
		if [[ -z "$owner" && -n "$claim_file" ]]; then
			owner="$(task_field "$claim_file" owner)"
		fi

		ttl=''
		[[ -n "$claim_file" ]] && ttl="$(lease_remaining "$claim_file")"

		if ((no_remote)); then
			lock_state='?'
		elif printf '%s\n' "${remote_claim_ids[@]}" | grep -qx "$id"; then
			lock_state='yes'
		else
			lock_state='MISSING'
		fi

		work=''
		for branch in "${remote_task_branches[@]}"; do
			if [[ "$(branch_suffix "$branch")" == "$id"-* ]]; then
				work="$(branch_suffix "$branch")"
				work="${work#"$id"-}"
				break
			fi
		done

		overlap=''
		if [[ -n "$claim_file" ]]; then
			mapfile -t own_paths < <(task_list "$claim_file" claimed_paths)
			local conflicts
			conflicts="$(path_conflicts "$id" -- "${own_paths[@]}" 2>/dev/null || true)"
			if [[ -n "$conflicts" ]]; then
				overlap='!'$(printf '%s\n' "$conflicts" | sed -n 's/^  - \(T-[0-9]\{4\}\) .*/\1/p' | sort -u | paste -sd, -)
			fi
		fi

		if [[ -n "$claim_file" ]] && ((!no_remote)) && [[ "$lock_state" == 'MISSING' ]]; then
			problems+=("$id : лиз в tasks/claims есть, а claim/$id в origin отсутствует — лок потерян.")
		fi
		if [[ "$ttl" == 'EXPIRED' ]]; then
			problems+=("$id : лиз просрочен (owner=$owner). Можно --takeover.")
		fi
		if [[ -z "$claim_file" ]] && [[ "$lock_state" == 'yes' ]]; then
			problems+=("$id : есть claim/$id, но нет файла tasks/claims/$id.md — расхождение слоёв A и B.")
		fi
		# Закрытая задача (done/blocked) держит ветку до merge — это не «брошенная работа».
		if [[ -z "$claim_file" ]] && [[ -n "$work" ]] && [[ "$status" != 'done' ]] && [[ "$status" != 'blocked' ]]; then
			problems+=("$id : ветка работы task/$id-* жива, а лиза нет — работа брошена.")
		fi
		if [[ -n "$overlap" ]]; then
			problems+=("$id : пересечение файлов с ${overlap#!}")
		fi

		r_id+=("$id")
		r_status+=("$status")
		r_dir+=("$dir")
		r_owner+=("$( [[ -z "$owner" ]] && printf '%s' '-' || printf '%s' "$owner" )")
		r_ttl+=("$( [[ -z "$ttl" ]] && printf '%s' '-' || printf '%s' "$ttl" )")
		r_lock+=("$lock_state")
		r_branch+=("$( [[ -z "$work" ]] && printf '%s' '-' || printf '%s' "$work" )")
		r_overlap+=("$( [[ -z "$overlap" ]] && printf '%s' '-' || printf '%s' "${overlap#!}" )")
	done < <(collect_tasks)

	if ((${#r_id[@]} == 0)); then
		warn 'Задач не найдено: tasks/ пуст.'
		return 0
	fi

	# ------------------------------------------------------------- таблица ----
	local -a headers=('ID' 'STATUS' 'DIR' 'OWNER' 'TTL' 'LOCKREF' 'BRANCH' 'OVERLAP')
	local -a widths=(0 0 0 0 0 0 0 0)
	local i w
	for w in "${!headers[@]}"; do widths[w]=${#headers[w]}; done
	for i in "${!r_id[@]}"; do
		local -a cells=("${r_id[i]}" "${r_status[i]}" "${r_dir[i]}" "${r_owner[i]}" "${r_ttl[i]}" "${r_lock[i]}" "${r_branch[i]}" "${r_overlap[i]}")
		for w in "${!cells[@]}"; do
			((${#cells[w]} > widths[w])) && widths[w]=${#cells[w]}
		done
	done

	print_row() {
		local idx=0 cell
		for cell in "$@"; do
			printf '%-*s' "$((widths[idx] + 2))" "$cell"
			idx=$((idx + 1))
		done
		printf '\n'
	}

	print_row "${headers[@]}"
	for w in "${!widths[@]}"; do
		printf '%-*s' "$((widths[w] + 2))" "$(printf '%*s' "${widths[w]}" '' | tr ' ' '-')"
	done
	printf '\n'
	for i in "${!r_id[@]}"; do
		print_row "${r_id[i]}" "${r_status[i]}" "${r_dir[i]}" "${r_owner[i]}" "${r_ttl[i]}" "${r_lock[i]}" "${r_branch[i]}" "${r_overlap[i]}"
	done

	# ------------------------------------------------------------- итоги ----
	local free_count=0 free_ids=''
	for i in "${!r_id[@]}"; do
		if [[ "${r_status[i]}" == 'todo' && "${r_owner[i]}" == '-' ]]; then
			free_count=$((free_count + 1))
			free_ids+="${r_id[i]}, "
		fi
	done
	ok "Свободных задач: $free_count"
	if ((free_count > 0)); then
		printf '  %s\n' "${free_ids%, }"
	fi

	if ((${#problems[@]} > 0)); then
		printf '\n'
		warn 'Требует внимания:'
		local p
		for p in "${problems[@]}"; do printf '  - %s\n' "$p"; done
		return 1
	fi
	ok 'Расхождений между tasks/ и origin нет.'
}

main "$@"
