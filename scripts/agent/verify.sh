#!/usr/bin/env bash
#
# Bash-версия scripts/agent/verify.ps1 — проверки проекта перед PR:
# валидность задач, гигиена git, импорт Godot.
#
# Не требует установленного Godot: если бинарь не найден, проверка импорта
# пропускается с предупреждением. Код возврата 1 при любой ошибке.
#
#   scripts/agent/verify.sh
#   scripts/agent/verify.sh --selftest   # только механизм задач

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent/agent_common.sh
source "$SCRIPT_DIR/agent_common.sh"

usage() {
	cat <<'EOF'
Проверки перед PR: задачи, лизы, гигиена git, импорт Godot.

Использование:
  verify.sh [--selftest]

Параметры:
      --selftest  проверить только механизм задач (разбор front matter, пути)
  -h, --help      эта справка
EOF
}

declare -a errors=()
declare -a warnings=()

add_error() { errors+=("$1"); }
add_warning() { warnings+=("$1"); }

VALID_STATUS=(todo claimed in-progress review done blocked)

selftest() {
	step 'Самотест механизма задач'
	local fail=0

	# Регресс-тест: путь к корню не должен зависеть от разделителя ОС.
	if [[ -f "$REPO_ROOT/project.godot" ]]; then
		ok "корень репозитория определён: $REPO_ROOT"
	else
		add_error "REPO_ROOT вернул '$REPO_ROOT', где нет project.godot."
		fail=$((fail + 1))
	fi
	if [[ "$REPO_ROOT" == *'\.\.'* ]]; then
		add_error 'в пути к корню остался обратный слэш как разделитель — сломается на Linux.'
		fail=$((fail + 1))
	fi

	local a b expect got
	while IFS=$'\t' read -r a b expect; do
		if path_overlap "$a" "$b"; then got='true'; else got='false'; fi
		if [[ "$got" == "$expect" ]]; then
			ok "overlap '$a' vs '$b' = $got"
		else
			add_error "overlap '$a' vs '$b': ожидалось $expect, получено $got"
			fail=$((fail + 1))
		fi
	done <<'CASES'
scripts/MovementCat.gd	scripts/MovementCat.gd	true
assets/sprites/cat	assets/sprites/cat/cat_idle1.png	true
assets/sprites/cat	assets/sprites/cat2/x.png	false
scripts/MovementCat.gd	scripts/MovementDog.gd	false
scenes/Level_Cat_Cemetry.tscn	scenes	true
PROJECT.GODOT	project.godot	true
project.godot	assets/x.png	false
CASES

	local sample
	sample="$(mktemp "${TMPDIR:-/tmp}/ghost-task-XXXXXX")"

	# Одиночная строка вместо списка — самая частая причина ложных падений.
	local -a single=()
	cat >"$sample" <<'SINGLE'
---
id: T-0998
paths: scripts/Only.gd
---
SINGLE
	mapfile -t single < <(task_list "$sample" paths)
	if ((${#single[@]} == 1)) && [[ "${single[0]}" == 'scripts/Only.gd' ]]; then
		ok 'одиночная строка приведена к списку из одного элемента'
	else
		add_error "одиночное значение разобрано неверно: ${single[*]:-<пусто>}"
		fail=$((fail + 1))
	fi
	cat >"$sample" <<'SAMPLE'
---
id: T-0999
title: Проверка разбора
status: todo
owner: null
paths:
  - scripts/A.gd
  - "scenes/B.tscn"
depends_on: [T-0001, T-0002]
---

## Контекст
SAMPLE

	local -a paths=() deps=()
	mapfile -t paths < <(task_list "$sample" paths)
	mapfile -t deps < <(task_list "$sample" depends_on)
	if ((${#paths[@]} == 2)) && [[ "${paths[1]}" == 'scenes/B.tscn' ]]; then
		ok "блочный список paths разобран: ${paths[*]}"
	else
		add_error "блочный список paths разобран неверно: ${paths[*]:-<пусто>}"
		fail=$((fail + 1))
	fi
	if ((${#deps[@]} == 2)); then
		ok "inline-список depends_on разобран: ${deps[*]}"
	else
		add_error "inline-список depends_on разобран неверно: ${deps[*]:-<пусто>}"
		fail=$((fail + 1))
	fi
	if [[ -z "$(task_field "$sample" owner)" ]]; then
		ok 'null разобран как пустое значение'
	else
		add_error "'null' не превратился в пустое значение"
		fail=$((fail + 1))
	fi
	rm -f "$sample"

	printf '\n'
	if ((fail > 0)); then
		err "Самотест провален ($fail)."
		return 1
	fi
	ok 'Самотест пройден.'
}

check_tasks() {
	step '1. Проверка задач в tasks/'
	local -a files=()
	local f
	mapfile -t files < <(
		for f in "$TASKS_DIR"/T-*.md; do [[ -e "$f" ]] && printf '%s\n' "$f"; done
		for f in "$DONE_DIR"/T-*.md; do [[ -e "$f" ]] && printf '%s\n' "$f"; done
	)

	if ((${#files[@]} == 0)); then
		add_warning 'В tasks/ нет задач.'
	fi

	declare -gA SEEN_IDS=()
	local file name id status dir p
	local -a paths=()
	for file in "${files[@]}"; do
		name="$(basename "$file")"
		[[ "$file" == "$DONE_DIR"/* ]] && dir='done' || dir='tasks'
		id="$(task_field "$file" id)"
		if ! [[ "$id" =~ ^T-[0-9]{4}$ ]]; then
			add_error "$name: поле id отсутствует или некорректно ('$id')."
			continue
		fi
		[[ "$name" == "$id"-* ]] || add_error "$name: имя файла не начинается с $id-."
		if [[ -n "${SEEN_IDS[$id]:-}" ]]; then
			add_error "$name: дубликат id $id."
		else
			SEEN_IDS["$id"]="$file"
		fi

		status="$(task_field "$file" status)"
		if [[ ! " ${VALID_STATUS[*]} " == *" $status "* ]]; then
			add_error "$name: неизвестный status '$status'."
		fi

		mapfile -t paths < <(task_list "$file" paths)
		if ((${#paths[@]} == 0)) && [[ "$status" != 'done' ]]; then
			add_error "$name: пустое поле paths."
		fi
		for p in "${paths[@]}"; do
			if [[ "$p" == /* || "$p" =~ ^[A-Za-z]: ]]; then
				add_error "$name: путь '$p' должен быть относительным от корня репозитория."
			fi
		done

		if [[ "$status" == 'done' && "$dir" != 'done' ]]; then
			add_error "$name: status=done, но файл не в tasks/done/."
		fi
		# blocked в tasks/done/ — нормальный результат release.sh --abort.
		if [[ "$status" != 'done' && "$status" != 'blocked' && "$dir" == 'done' ]]; then
			add_error "$name: файл в tasks/done/, но status=$status."
		fi
	done
	ok "Задач: ${#files[@]}"
}

check_claims() {
	step '2. Проверка лизов tasks/claims/'
	local -a claims=()
	mapfile -t claims < <(active_claims)

	local claim id owner
	for claim in "${claims[@]}"; do
		id="$(task_field "$claim" id)"
		owner="$(task_field "$claim" owner)"
		if [[ -z "${SEEN_IDS[$id]:-}" ]]; then
			add_error "claims/$(basename "$claim"): нет соответствующей задачи $id."
		fi
		if [[ -z "$owner" ]]; then
			add_error "claims/$(basename "$claim"): пустой owner."
		fi
		if lease_expired "$claim"; then
			add_warning "claims/$(basename "$claim"): лок просрочен, задачу можно перехватить."
		fi
	done
	ok "Лизов: ${#claims[@]}"

	local i j pa pb
	local -a paths_a=() paths_b=()
	for ((i = 0; i < ${#claims[@]}; i++)); do
		for ((j = i + 1; j < ${#claims[@]}; j++)); do
			mapfile -t paths_a < <(task_list "${claims[i]}" claimed_paths)
			mapfile -t paths_b < <(task_list "${claims[j]}" claimed_paths)
			for pa in "${paths_a[@]}"; do
				for pb in "${paths_b[@]}"; do
					if path_overlap "$pa" "$pb"; then
						add_error "Лизы $(task_field "${claims[i]}" id) и $(task_field "${claims[j]}" id) захватили один файл: '$pa' / '$pb'."
					fi
				done
			done
		done
	done
}

check_git_hygiene() {
	step '3. Гигиена репозитория'
	local -a tracked=()
	mapfile -t tracked < <(git_run ls-files)

	local -a patterns=(
		'^\.godot/'
		'^build/|^builds/|^export/'
		'\.(exe|pck|apk|aab|dmg)$'
		'\.(keystore|jks)$'
		'^\.vs/|\.user$|\.suo$'
	)
	local -a whats=(
		'кэш Godot .godot/'
		'каталог сборки'
		'артефакт сборки'
		'ключ подписи'
		'файл IDE'
	)
	local i file
	for i in "${!patterns[@]}"; do
		for file in "${tracked[@]}"; do
			if [[ "$file" =~ ${patterns[i]} ]]; then
				add_error "В индексе лишний файл (${whats[i]}): $file"
			fi
		done
	done
	ok "Файлов в индексе: ${#tracked[@]}"

	# .import и .uid — производные файлы Godot: их нельзя править руками,
	# но и удалять из индекса нельзя (иначе ломаются uid-ссылки в сценах).
	for file in "${tracked[@]}"; do
		if [[ "$file" =~ ^assets/.*\.(png|mp3|ogg|wav|ttf)$ ]]; then
			[[ -f "$REPO_ROOT/$file.import" ]] ||
				add_warning "Нет .import для ассета: $file (переимпортируйте проект в Godot)."
		fi
	done
}

check_godot() {
	step '4. Проверка проекта Godot'
	local godot='' candidate
	for candidate in godot Godot godot4; do
		if command -v "$candidate" >/dev/null 2>&1; then
			godot="$(command -v "$candidate")"
			break
		fi
	done

	if [[ -z "$godot" ]]; then
		add_warning 'Godot не найден в PATH — проверка импорта пропущена.'
		return 0
	fi

	ok "Godot: $godot"

	# Свежий клон не имеет .godot/ — без импорта main scene не разрешается по UID.
	if [[ ! -d "$REPO_ROOT/.godot" ]]; then
		warn 'Проект не импортирован (.godot/ нет) — выполняю первичный импорт…'
		"$godot" --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 ||
			add_warning 'Первичный импорт Godot завершился с ошибкой — проверка загрузки может быть недостоверной.'
	fi

	local out='' status=0
	out="$("$godot" --headless --path "$REPO_ROOT" --quit 2>&1)" || status=$?
	if ((status != 0)); then
		add_error "Godot завершился с кодом ${status}:"$'\n'"$out"
	fi

	local line hits=0
	while IFS= read -r line; do
		[[ -n "$line" ]] || continue
		if [[ "$line" =~ SCRIPT\ ERROR|Parse\ Error|Failed\ to\ load ]]; then
			add_error "Godot: $line"
			hits=$((hits + 1))
		fi
	done <<<"$out"
	if ((hits == 0 && status == 0)); then
		ok 'Проект загружается без ошибок скриптов.'
	fi
}

main() {
	local selftest_only=0

	while (($#)); do
		case "$1" in
		--selftest | -s)
			selftest_only=1
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

	if ((selftest_only)); then
		selftest || return 1
		return 0
	fi

	check_tasks
	check_claims
	check_git_hygiene
	check_godot

	printf '\n'
	local w
	for w in "${warnings[@]}"; do warn "$w"; done
	if ((${#errors[@]} > 0)); then
		local e
		for e in "${errors[@]}"; do err "$e"; done
		err "Проверка провалена: ${#errors[@]} ошибок."
		return 1
	fi
	ok 'Все проверки пройдены.'
}

main "$@"
