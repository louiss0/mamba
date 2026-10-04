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

_rig_rig_deploy_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_rig_deploy_tag_values=(
)

_rig_rig_deploy_replicas_values=(
)

_rig_rig_deploy_level_values=(
  'debug'
  'info'
  'warn'
)

_rig_rig_deploy_token_values=(
)

_rig_rig_deploy_host_values=(
)

_rig_rig_deploy_port_values=(
)

_rig_rig_deploy_log_values=(
)

_rig_rig_deploy_report_values=(
)

_rig_rig_deploy_database_dsn_values=(
)

_rig_rig_deploy_database_pool_size_values=(
)

_rig_rig_deploy_database_pool_mode_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_rig_deploy_options=(
  ['--format']='_rig_rig_deploy_format_values'
  ['--tag']='_rig_rig_deploy_tag_values'
  ['-t']='_rig_rig_deploy_tag_values'
  ['--replicas']='_rig_rig_deploy_replicas_values'
  ['--level']='_rig_rig_deploy_level_values'
  ['--token']='_rig_rig_deploy_token_values'
  ['-k']='_rig_rig_deploy_token_values'
  ['--host']='_rig_rig_deploy_host_values'
  ['--port']='_rig_rig_deploy_port_values'
  ['--log']='_rig_rig_deploy_log_values'
  ['--report']='_rig_rig_deploy_report_values'
  ['--database.dsn']='_rig_rig_deploy_database_dsn_values'
  ['--database.pool.size']='_rig_rig_deploy_database_pool_size_values'
  ['--database.pool.mode']='_rig_rig_deploy_database_pool_mode_values'
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
      _mamba_filter_option '--format' "$current" "${_rig_rig_deploy_format_values[@]}"
      return
      ;;
    --level=*)
      _mamba_filter_option '--level' "$current" "${_rig_rig_deploy_level_values[@]}"
      return
      ;;
    --database.pool.mode=*)
      _mamba_filter_option '--database.pool.mode' "$current" "${_rig_rig_deploy_database_pool_mode_values[@]}"
      return
      ;;
  esac

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_rig_deploy_format_values[@]}"
      return
      ;;
    --level)
      _mamba_filter "$current" "${_rig_rig_deploy_level_values[@]}"
      return
      ;;
    --database.pool.mode)
      _mamba_filter "$current" "${_rig_rig_deploy_database_pool_mode_values[@]}"
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
