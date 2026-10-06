if ((BASH_VERSINFO[0] < 4)); then
  printf '%s\n' 'rig: completion requires bash 4 or newer' >&2
  return 0 2>/dev/null || exit 1
fi
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

_mamba_filter_separate() {
  local numeric="$1" current="$2"
  shift 2
  local candidate
  local -a accepted=()
  for candidate in "$@"; do
    if [[ "$numeric" == true || "$candidate" != -* || "$candidate" == - ]]; then
      accepted+=("$candidate")
    fi
  done
  _mamba_filter "$current" "${accepted[@]}"
}

_mamba_valid_short_value() {
  local head="$1"
  shift
  local prefix="${head:1:${#head}-2}"
  local index flag found
  for ((index = 0; index < ${#prefix}; index++)); do
    found=0
    for flag in "$@"; do
      [[ "$flag" == "-${prefix:index:1}" ]] && found=1
    done
    ((found)) || return 1
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

declare -A _rig_options=(
)

declare -A _rig_command_routes=(
  ['rig|rig']='_rig_rig_completion'
  ['rig_rig|deploy']='_rig_rig_deploy_completion'
  ['rig_rig|ship']='_rig_rig_deploy_completion'
  ['rig_rig|status']='_rig_rig_status_completion'
)

declare -A _rig_value_options=(
  ['rig_rig_deploy|--format']=1
  ['rig_rig_deploy|--tag']=1
  ['rig_rig_deploy|-t']=1
  ['rig_rig_deploy|--replicas']=1
  ['rig_rig_deploy|--level']=1
  ['rig_rig_deploy|--token']=1
  ['rig_rig_deploy|-k']=1
  ['rig_rig_deploy|--host']=1
  ['rig_rig_deploy|--port']=1
  ['rig_rig_deploy|--log']=1
  ['rig_rig_deploy|--report']=1
  ['rig_rig_deploy|--database.dsn']=1
  ['rig_rig_deploy|--database.pool.size']=1
  ['rig_rig_deploy|--database.pool.mode']=1
)

# Completion fixture.
# Inputs for rig
_rig_rig_flags=(
  '-h'
  '--help'
)

declare -A _rig_rig_options=(
)

# Deploy a build.
#
# Ship a build to an environment.
# Inputs for rig deploy
_rig_rig_deploy_flags=(
  '-h'
  '--help'
  '--dry-run'
  '--no-dry-run'
  '-r'
  '--retries'
)

_rig_rig_deploy_format_5Fvalues=(
  'text'
  'json'
  'yaml'
)

_rig_rig_deploy_tag_5Fvalues=(
)

_rig_rig_deploy_replicas_5Fvalues=(
)

_rig_rig_deploy_level_5Fvalues=(
  'debug'
  'info'
  'warn'
)

_rig_rig_deploy_token_5Fvalues=(
)

_rig_rig_deploy_host_5Fvalues=(
)

_rig_rig_deploy_port_5Fvalues=(
)

_rig_rig_deploy_log_5Fvalues=(
)

_rig_rig_deploy_report_5Fvalues=(
)

_rig_rig_deploy_database_2Edsn_5Fvalues=(
)

_rig_rig_deploy_database_2Epool_2Esize_5Fvalues=(
)

_rig_rig_deploy_database_2Epool_2Emode_5Fvalues=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_rig_deploy_options=(
  ['--format']='_rig_rig_deploy_format_5Fvalues'
  ['--tag']='_rig_rig_deploy_tag_5Fvalues'
  ['-t']='_rig_rig_deploy_tag_5Fvalues'
  ['--replicas']='_rig_rig_deploy_replicas_5Fvalues'
  ['--level']='_rig_rig_deploy_level_5Fvalues'
  ['--token']='_rig_rig_deploy_token_5Fvalues'
  ['-k']='_rig_rig_deploy_token_5Fvalues'
  ['--host']='_rig_rig_deploy_host_5Fvalues'
  ['--port']='_rig_rig_deploy_port_5Fvalues'
  ['--log']='_rig_rig_deploy_log_5Fvalues'
  ['--report']='_rig_rig_deploy_report_5Fvalues'
  ['--database.dsn']='_rig_rig_deploy_database_2Edsn_5Fvalues'
  ['--database.pool.size']='_rig_rig_deploy_database_2Epool_2Esize_5Fvalues'
  ['--database.pool.mode']='_rig_rig_deploy_database_2Epool_2Emode_5Fvalues'
)

_rig_rig_deploy_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  if [[ "$_mamba_after_separator" == 1 ]]; then
    _complete_rig_rig_deploy_variadic "$current"
    return
  fi

  case "$current" in
    --format=*)
      if [[ "$current" != --* ]] && ! _mamba_valid_short_value "${current%%=*}" "${_rig_rig_deploy_flags[@]}"; then return; fi
      _mamba_filter_option "${current%%=*}" "$current" "${_rig_rig_deploy_format_5Fvalues[@]}"
      return
      ;;
    --level=*)
      if [[ "$current" != --* ]] && ! _mamba_valid_short_value "${current%%=*}" "${_rig_rig_deploy_flags[@]}"; then return; fi
      _mamba_filter_option "${current%%=*}" "$current" "${_rig_rig_deploy_level_5Fvalues[@]}"
      return
      ;;
    --database.pool.mode=*)
      if [[ "$current" != --* ]] && ! _mamba_valid_short_value "${current%%=*}" "${_rig_rig_deploy_flags[@]}"; then return; fi
      _mamba_filter_option "${current%%=*}" "$current" "${_rig_rig_deploy_database_2Epool_2Emode_5Fvalues[@]}"
      return
      ;;
  esac

  case "$previous" in
    --format)
      _mamba_filter_separate false "$current" "${_rig_rig_deploy_format_5Fvalues[@]}"
      return
      ;;
    --level)
      _mamba_filter_separate false "$current" "${_rig_rig_deploy_level_5Fvalues[@]}"
      return
      ;;
    --database.pool.mode)
      _mamba_filter_separate false "$current" "${_rig_rig_deploy_database_2Epool_2Emode_5Fvalues[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_rig_deploy_flags[@]}" "${!_rig_rig_deploy_options[@]}"
      ;;
    *)
      _complete_rig_rig_deploy_positional "$current"
      ;;
  esac
}

_complete_rig_rig_deploy_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

_complete_rig_rig_deploy_variadic() {
  local current="$1"
}

# Report status.
# Inputs for rig status
_rig_rig_status_flags=(
  '-h'
  '--help'
  '-w'
  '--watch'
)

declare -A _rig_rig_status_options=(
)

_rig_rig_status_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  if [[ "$_mamba_after_separator" == 1 ]]; then
    _complete_rig_rig_status_variadic "$current"
    return
  fi

  case "$current" in
  esac

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_rig_status_flags[@]}" "${!_rig_rig_status_options[@]}"
      ;;
    *)
      _complete_rig_rig_status_positional "$current"
      ;;
  esac
}

_complete_rig_rig_status_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

_complete_rig_rig_status_variadic() {
  local current="$1"
}

_rig_rig_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  if [[ "$_mamba_after_separator" == 1 ]]; then
    _complete_rig_rig_variadic "$current"
    return
  fi

  case "$current" in
  esac

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_rig_flags[@]}" "${!_rig_rig_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'deploy' 'ship' 'status'
      _complete_rig_rig_positional "$current"
      ;;
  esac
}

_complete_rig_rig_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

_complete_rig_rig_variadic() {
  local current="$1"
}

_rig_root_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  if [[ "$_mamba_after_separator" == 1 ]]; then
    _complete_rig_variadic "$current"
    return
  fi

  case "$current" in
  esac

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${!_rig_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'rig'
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
    if [[ -n "${_rig_value_options["$path|$token"]}" && "${COMP_WORDS[index + 1]}" != -* ]]; then
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
