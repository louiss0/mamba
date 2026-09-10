_mamba_filter() {
  local current="$1"
  shift
  COMPREPLY=()

  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$current"* ]]; then
      COMPREPLY+=("$candidate")
    fi
  done
}

_mamba_filter_option() {
  local option="$1"
  local current="$2"
  shift 2
  COMPREPLY=()

  local value="${current#*=}"
  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$value"* ]]; then
      COMPREPLY+=("$option=$candidate")
    fi
  done
}

# Completion fixture.
# Global inputs for rig
_rig_flags=(
  '-h'
  '--help'
)

_rig_format_values=(
  'text'
  'json'
)

declare -A _rig_options=(
  ['--format']='_rig_format_values'
)

declare -A _rig_command_routes=(
)

declare -A _rig_value_options=(
  ['rig|--format']=1
)

_rig_root_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  if [[ "$_mamba_after_separator" == 1 ]]; then
    _complete_rig_variadic "$current"
    return
  fi

  case "$current" in
    --format=*)
      _mamba_filter_option '--format' "$current" "${_rig_format_values[@]}"
      return
      ;;
  esac

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${!_rig_options[@]}"
      ;;
    *)
      _complete_rig_positional "$current"
      ;;
  esac
}

_complete_rig_positional() {
  local current="$1"
}

_complete_rig_variadic() {
  local current="$1"
}

_rig_completion() {
  COMPREPLY=()
  local path='rig'
  local handler='_rig_root_completion'
  local index token route
  local positional_index=0
  local variadic_index=0
  local after_separator=0

  for ((index = 1; index < COMP_CWORD; index++)); do
    token="${COMP_WORDS[index]}"
    if ((after_separator)); then
      ((variadic_index++))
      continue
    fi
    if [[ "$token" == -- ]]; then
      after_separator=1
      continue
    fi
    if [[ -n "${_rig_value_options["$path|$token"]}" ]]; then
      ((index++))
      continue
    fi
    if [[ "$token" == --*=* ]]; then
      local option="${token%%=*}"
      if [[ -n "${_rig_value_options["$path|$option"]}" ]]; then
        continue
      fi
    fi
    route="${_rig_command_routes["$path|$token"]}"
    if [[ -n "$route" ]]; then
      handler="$route"
      path="${route#_}"
      path="${path%_completion}"
      positional_index=0
      continue
    fi
    if [[ "$token" == -* ]]; then
      continue
    fi
    ((positional_index++))
  done

  _mamba_after_separator=$after_separator
  _mamba_positional_index=$positional_index
  _mamba_variadic_index=$variadic_index
  "$handler"
}

complete -F _rig_completion rig
