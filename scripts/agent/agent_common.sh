#!/usr/bin/env bash
# Общие функции для scripts/agent/*.sh — bash-версия AgentCommon.ps1 для Linux/macOS.
# Не запускается напрямую: подключается через `source`.
#
# Поведение повторяет PowerShell-оригинал: разбор front matter задач, TTL лизов,
# сравнение путей и вызовы git. Стиль — те же сообщения на русском.
#
# Требуется bash 4+ (ассоциативные массивы не используются, но нужны `mapfile`
# и `${var,,}`) и GNU/BSD date.

# shellcheck shell=bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_DIR="$REPO_ROOT/tasks"
CLAIMS_DIR="$TASKS_DIR/claims"
DONE_DIR="$TASKS_DIR/done"
DEFAULT_LEASE_HOURS=4

# ---------------------------------------------------------------- вывод ----

if [[ -t 1 ]]; then
	C_STEP=$'\e[36m'
	C_OK=$'\e[32m'
	C_WARN=$'\e[33m'
	C_ERR=$'\e[31m'
	C_OFF=$'\e[0m'
else
	C_STEP=''
	C_OK=''
	C_WARN=''
	C_ERR=''
	C_OFF=''
fi

step() { printf '%s==> %s%s\n' "$C_STEP" "$*" "$C_OFF"; }
ok() { printf '%s[ok] %s%s\n' "$C_OK" "$*" "$C_OFF"; }
warn() { printf '%s[!] %s%s\n' "$C_WARN" "$*" "$C_OFF"; }
err() { printf '%s[x] %s%s\n' "$C_ERR" "$*" "$C_OFF" >&2; }
die() {
	err "$*"
	exit 1
}

# ------------------------------------------------------------------ git ----

git_run() { git -C "$REPO_ROOT" "$@"; }

git_switch() {
	# `git switch` появился в git 2.23; на старых системах откатываемся на checkout.
	if git_run switch "$@" 2>/dev/null; then return 0; fi
	git_run checkout "$@" 2>/dev/null
}

set_git_identity_if_missing() {
	# Для агентов без настроенного git: коммиты лока должны быть подписаны хоть как-то.
	if [[ -z "$(git_run config user.name 2>/dev/null || true)" ]]; then
		git_run config user.name ghost-agent || true
	fi
	if [[ -z "$(git_run config user.email 2>/dev/null || true)" ]]; then
		git_run config user.email agent@localhost || true
	fi
}

worktree_dirty_entries() { git_run status --porcelain; }

test_clean_worktree() { [[ -z "$(worktree_dirty_entries)" ]]; }

remote_branch_names() {
	# Имена удалённых веток по glob-шаблону (по умолчанию '*'). Читаем сервер:
	# локальный кэш мог устареть, а от этого зависит блокировка.
	local pattern="${1:-*}"
	git_run ls-remote --heads origin "$pattern" 2>/dev/null |
		sed -n 's#.*refs/heads/\(.*\)$#\1#p'
}

branch_prefix() {
	# GitHub может создавать ветки с префиксами (user/, bot/). Наш лок — 'claim/' на любом уровне.
	local name="$1"
	if [[ "$name" =~ (^|/)claim/ ]]; then
		printf 'claim'
	elif [[ "$name" =~ (^|/)task/ ]]; then
		printf 'task'
	fi
}

branch_suffix() {
	# 'user/claim/T-0002' -> 'T-0002'; 'task/T-0002-menu' -> 'T-0002-menu'
	local name="$1"
	if [[ "$name" =~ (^|/)(claim|task)/(.+)$ ]]; then
		printf '%s' "${BASH_REMATCH[3]}"
	else
		printf '%s' "$name"
	fi
}

remote_branch_exists() {
	# remote_branch_exists claim T-0002 -> на origin есть лок задачи (с любым префиксом).
	local prefix="$1" tail_name="$2" name
	while IFS= read -r name; do
		[[ -n "$name" ]] || continue
		if [[ "$(branch_prefix "$name")" == "$prefix" && "$(branch_suffix "$name")" == "$tail_name" ]]; then
			return 0
		fi
	done < <(remote_branch_names '*')
	return 1
}

claim_branch_name() {
	# Настоящее имя лок-ветки: то, что уже есть на origin, иначе claim/<Task>.
	local task="$1" name
	while IFS= read -r name; do
		[[ -n "$name" ]] || continue
		if [[ "$(branch_prefix "$name")" == 'claim' && "$(branch_suffix "$name")" == "$task" ]]; then
			printf '%s' "$name"
			return 0
		fi
	done < <(remote_branch_names '*')
	printf 'claim/%s' "$task"
}

remove_remote_ref() {
	# Удаляет ветку на origin по точному имени. Возвращает 0 при успехе.
	local ref="$1"
	git_run push origin --delete "$ref" >/dev/null 2>&1
}

# ------------------------------------------------------------ front matter ----

trim() {
	local s="${1-}"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

strip_quotes() {
	local s="${1-}"
	s="${s%\"}"
	s="${s#\"}"
	s="${s%\'}"
	s="${s#\'}"
	printf '%s' "$s"
}

fm_pairs() {
	# Печатает front matter парами "ключ<TAB>значение" (по строке на каждое значение).
	# Поддерживает скаляры, inline-списки [a, b] и блочные списки через перенос строки.
	awk '
		NR == 1 {
			if ($0 !~ /^---[ \t]*$/) { exit 2 }
			infm = 1
			next
		}
		infm && $0 ~ /^---[ \t]*$/ { exit }
		!infm { next }
		{
			if ($0 ~ /^[ \t]*-[ \t]+/) {
				if (listkey != "") {
					v = $0
					sub(/^[ \t]*-[ \t]+/, "", v)
					sub(/[ \t]+$/, "", v)
					printf "%s\t%s\n", listkey, v
				}
				next
			}
			if (match($0, /^[A-Za-z_][A-Za-z0-9_-]*:/)) {
				k = substr($0, 1, RLENGTH - 1)
				v = substr($0, RLENGTH + 1)
				gsub(/^[ \t]+|[ \t]+$/, "", v)
				if (v == "") { listkey = k; next }
				listkey = ""
				printf "%s\t%s\n", k, v
			}
		}
	' "$1"
}

task_field() {
	# Первое значение поля; null/~/пусто -> пустая строка.
	local file="$1" key="$2" k v
	local value=""
	while IFS=$'\t' read -r k v; do
		if [[ "$k" == "$key" ]]; then
			value="$v"
			break
		fi
	done < <(fm_pairs "$file")
	value="$(strip_quotes "$value")"
	case "$value" in
	null | '~') value='' ;;
	esac
	printf '%s' "$value"
}

task_list() {
	# Все значения поля как массив строк: блочный список и inline [a, b].
	local file="$1" key="$2" k v item
	while IFS=$'\t' read -r k v; do
		[[ "$k" == "$key" ]] || continue
		if [[ "$v" =~ ^\[(.*)\]$ ]]; then
			local inner="${BASH_REMATCH[1]}"
			[[ -n "$(trim "$inner")" ]] || continue
			while IFS= read -r item; do
				item="$(strip_quotes "$(trim "$item")")"
				[[ -n "$item" ]] && printf '%s\n' "$item"
			done < <(tr ',' '\n' <<<"$inner")
		else
			printf '%s\n' "$(strip_quotes "$(trim "$v")")"
		fi
	done < <(fm_pairs "$file")
}

task_status() { task_field "$1" status; }

set_task_field() {
	# Меняет одно скалярное поле front matter, не трогая остальной файл.
	local file="$1" key="$2" value="$3" tmp
	tmp="$(mktemp)"
	awk -v k="$key" -v v="$value" '
		BEGIN { infm = 0; done = 0 }
		NR == 1 {
			if ($0 ~ /^---[ \t]*$/) { infm = 1 }
			print
			next
		}
		infm && $0 ~ /^---[ \t]*$/ {
			if (!done) { print k ": " v; done = 1 }
			infm = 0
			print
			next
		}
		infm && !done && index($0, k ":") == 1 {
			print k ": " v
			done = 1
			next
		}
		{ print }
	' "$file" >"$tmp"
	mv -- "$tmp" "$file"
}

add_task_note() {
	# Дописывает строку в конец файла задачи — история takeover и релиза.
	local file="$1" note="$2"
	printf -- '- %s — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$note" >>"$file"
}

find_task() {
	# T-0012 -> tasks/T-0012-*.md
	local id="${1-}"
	id="$(printf '%s' "$id" | tr '[:lower:]' '[:upper:]')"
	[[ "$id" =~ ^T-[0-9]{4}$ ]] || die "Некорректный id задачи '$id'. Ожидается формат T-0001."

	local found=() file
	for file in "$TASKS_DIR/$id"-*.md; do
		[[ -e "$file" ]] && found+=("$file")
	done
	((${#found[@]} == 0)) && die "Задача $id не найдена в tasks/."
	if ((${#found[@]} > 1)); then
		printf -v names '%s, ' "${found[@]##*/}"
		die "Найдено несколько файлов для $id: ${names%, }."
	fi
	printf '%s' "${found[0]}"
}

initialize_task_system() {
	# Git не хранит пустые каталоги — без них проверки падают на первом запуске.
	mkdir -p "$TASKS_DIR" "$CLAIMS_DIR" "$DONE_DIR"
}

# ------------------------------------------------------------- ЛИЗЫ / TTL ----

iso_to_epoch() {
	# ISO-8601 UTC -> epoch. GNU date первым, затем BSD (macOS).
	local value="$1" out
	if out="$(date -u -d "$value" +%s 2>/dev/null)"; then
		printf '%s' "$out"
		return 0
	fi
	if out="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$value" +%s 2>/dev/null)"; then
		printf '%s' "$out"
		return 0
	fi
	return 1
}

format_lease_time() {
	# epoch -> 2026-10-31T12:00:00Z
	local epoch="$1"
	date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
		date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ
}

lease_expired() {
	# Просрочен ли лиз (файл tasks/claims/*.md). Нет TTL -> просрочен.
	local claim="$1" until_epoch now
	until_epoch="$(iso_to_epoch "$(task_field "$claim" lease_until)" || true)"
	[[ -z "$until_epoch" ]] && return 0
	now="$(date -u +%s)"
	if ((until_epoch <= now)); then return 0; fi
	return 1
}

lease_remaining() {
	local claim="$1" until_epoch now delta
	until_epoch="$(iso_to_epoch "$(task_field "$claim" lease_until)" || true)"
	if [[ -z "$until_epoch" ]]; then
		printf 'no-ttl'
		return 0
	fi
	now="$(date -u +%s)"
	delta=$((until_epoch - now))
	if ((delta <= 0)); then
		printf 'EXPIRED'
		return 0
	fi
	printf '%dh%02dm' $((delta / 3600)) $(((delta % 3600) / 60))
}

active_claims() {
	# Файлы лизов из tasks/claims/ (T-*.md).
	local file
	[[ -d "$CLAIMS_DIR" ]] || return 0
	for file in "$CLAIMS_DIR"/T-*.md; do
		[[ -e "$file" ]] && printf '%s\n' "$file"
	done
}

# ------------------------------------------------------------------ paths ----

normalize_repo_path() {
	local p="${1-}"
	p="$(printf '%s' "$p" | tr '\\' '/')"
	p="${p#./}"
	while [[ "$p" == */ ]]; do p="${p%/}"; done
	# Нижний регистр: на Windows/macOS регистр файлов не различается.
	printf '%s' "$p" | tr '[:upper:]' '[:lower:]'
}

path_overlap() {
	# Пересекаются ли два пути: равенство либо префикс по границе каталога.
	local a b
	a="$(normalize_repo_path "$1")"
	b="$(normalize_repo_path "$2")"
	[[ -z "$a" || -z "$b" ]] && return 1
	[[ "$a" == "$b" ]] && return 0
	[[ "$a" == "$b"/* || "$b" == "$a"/* ]]
}

path_conflicts() {
	# path_conflicts <ignore_id...> -- <path...>
	# Печатает строки конфликтов с активными лизами, кроме перечисленных id.
	local -a ignore=() paths=() claim_paths=()
	local arg seen_sep=0 claim id owner path claim_path hit=0

	for arg in "$@"; do
		if ((seen_sep == 0)) && [[ "$arg" == '--' ]]; then
			seen_sep=1
			continue
		fi
		if ((seen_sep == 0)); then ignore+=("$arg"); else paths+=("$arg"); fi
	done

	local claim_file
	while IFS= read -r claim_file; do
		[[ -n "$claim_file" ]] || continue
		id="$(task_field "$claim_file" id)"
		[[ -n "$id" ]] || id="$(basename "$claim_file")"
		local skip=0
		for arg in "${ignore[@]}"; do
			[[ "$arg" == "$id" ]] && skip=1
		done
		((skip)) && continue

		owner="$(task_field "$claim_file" owner)"
		mapfile -t claim_paths < <(task_list "$claim_file" paths)
		for path in "${paths[@]}"; do
			for claim_path in "${claim_paths[@]}"; do
				if path_overlap "$path" "$claim_path"; then
					printf "  - %s (%s) держит '%s' -> конфликт с '%s'\n" "$id" "$owner" "$claim_path" "$path"
					hit=1
				fi
			done
		done
	done < <(active_claims)

	((hit)) || return 0
}
