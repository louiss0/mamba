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

# A mock workstation-control CLI for harmless terminal simulations.
#
# rig only prints simulated operations. It never changes, inspects,
# connects to, or otherwise affects the computer.
# Global inputs for rig
_rig_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_options=(
  ['--format']='_rig_format_values'
)

declare -A _rig_command_routes=(
  ['rig|volume']='_rig_volume_completion'
  ['rig|vol']='_rig_volume_completion'
  ['rig|brightness']='_rig_brightness_completion'
  ['rig|bright']='_rig_brightness_completion'
  ['rig|power']='_rig_power_completion'
  ['rig|pwr']='_rig_power_completion'
  ['rig|process']='_rig_process_completion'
  ['rig|proc']='_rig_process_completion'
  ['rig|clean']='_rig_clean_completion'
  ['rig|sweep']='_rig_clean_completion'
  ['rig|completion']='_rig_completion_completion'
  ['rig|network']='_rig_network_completion'
  ['rig|net']='_rig_network_completion'
  ['rig_network|wifi']='_rig_network_wifi_completion'
  ['rig_network_wifi|connect']='_rig_network_wifi_connect_completion'
  ['rig_network_wifi|disconnect']='_rig_network_wifi_disconnect_completion'
  ['rig_network_wifi|scan']='_rig_network_wifi_scan_completion'
  ['rig_network_wifi|status']='_rig_network_wifi_status_completion'
  ['rig_network|dns']='_rig_network_dns_completion'
  ['rig_network_dns|get']='_rig_network_dns_get_completion'
  ['rig_network_dns|set']='_rig_network_dns_set_completion'
  ['rig_network_dns|reset']='_rig_network_dns_reset_completion'
  ['rig_network|proxy']='_rig_network_proxy_completion'
  ['rig_network|ping']='_rig_network_ping_completion'
  ['rig|profile']='_rig_profile_completion'
  ['rig|preset']='_rig_profile_completion'
  ['rig_profile|save']='_rig_profile_save_completion'
  ['rig_profile|apply']='_rig_profile_apply_completion'
  ['rig_profile|remove']='_rig_profile_remove_completion'
  ['rig_profile|list']='_rig_profile_list_completion'
)

declare -A _rig_value_options=(
  ['rig|--format']=1
  ['rig_volume|--format']=1
  ['rig_volume|--device']=1
  ['rig_volume|-d']=1
  ['rig_volume|--level']=1
  ['rig_volume|-l']=1
  ['rig_volume|--balance']=1
  ['rig_volume|-b']=1
  ['rig_volume|--channel']=1
  ['rig_volume|--channel-gain']=1
  ['rig_brightness|--format']=1
  ['rig_brightness|--level']=1
  ['rig_brightness|-l']=1
  ['rig_brightness|--gamma']=1
  ['rig_brightness|-g']=1
  ['rig_brightness|--temperature']=1
  ['rig_brightness|-t']=1
  ['rig_brightness|--contrast']=1
  ['rig_brightness|--display']=1
  ['rig_brightness|-d']=1
  ['rig_power|--format']=1
  ['rig_power|--delay']=1
  ['rig_power|-d']=1
  ['rig_power|--reason']=1
  ['rig_power|-r']=1
  ['rig_process|--format']=1
  ['rig_process|--priority']=1
  ['rig_process|--pid']=1
  ['rig_process|-p']=1
  ['rig_process|--name']=1
  ['rig_process|-n']=1
  ['rig_process|--cpu']=1
  ['rig_process|-c']=1
  ['rig_process|--limit.cpu.percent']=1
  ['rig_process|--limit.memory.mb']=1
  ['rig_process|--limit.io.read']=1
  ['rig_process|--limit.io.write']=1
  ['rig_clean|--format']=1
  ['rig_clean|--older-than']=1
  ['rig_clean|--larger-than']=1
  ['rig_clean|--exclude']=1
  ['rig_completion|--format']=1
  ['rig_completion|--shell']=1
  ['rig_network|--format']=1
  ['rig_network_wifi|--format']=1
  ['rig_network_wifi_connect|--format']=1
  ['rig_network_wifi_connect|--ssid']=1
  ['rig_network_wifi_connect|--password']=1
  ['rig_network_wifi_connect|--channel']=1
  ['rig_network_wifi_disconnect|--format']=1
  ['rig_network_wifi_disconnect|--ssid']=1
  ['rig_network_wifi_scan|--format']=1
  ['rig_network_wifi_scan|--channel']=1
  ['rig_network_wifi_status|--format']=1
  ['rig_network_dns|--format']=1
  ['rig_network_dns_get|--format']=1
  ['rig_network_dns_get|--interface']=1
  ['rig_network_dns_set|--format']=1
  ['rig_network_dns_set|--interface']=1
  ['rig_network_dns_set|--server']=1
  ['rig_network_dns_reset|--format']=1
  ['rig_network_dns_reset|--interface']=1
  ['rig_network_proxy|--format']=1
  ['rig_network_proxy|--http.host']=1
  ['rig_network_proxy|--http.port']=1
  ['rig_network_proxy|--https.host']=1
  ['rig_network_proxy|--https.port']=1
  ['rig_network_proxy|--socks.host']=1
  ['rig_network_proxy|--socks.port']=1
  ['rig_network_ping|--format']=1
  ['rig_network_ping|--count']=1
  ['rig_network_ping|--timeout']=1
  ['rig_profile|--format']=1
  ['rig_profile_save|--format']=1
  ['rig_profile_apply|--format']=1
  ['rig_profile_apply|--only']=1
  ['rig_profile_apply|--except']=1
  ['rig_profile_remove|--format']=1
  ['rig_profile_list|--format']=1
)

# Describe simulated audio input and output operations.
# Inputs for volume
_rig_volume_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '-m'
  '--mute'
  '-u'
  '--unmute'
)

_rig_volume_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_volume_device_values=(
)

_rig_volume_level_values=(
)

_rig_volume_balance_values=(
)

_rig_volume_channel_values=(
)

_rig_volume_channel_gain_values=(
)

declare -A _rig_volume_options=(
  ['--format']='_rig_volume_format_values'
  ['--device']='_rig_volume_device_values'
  ['-d']='_rig_volume_device_values'
  ['--level']='_rig_volume_level_values'
  ['-l']='_rig_volume_level_values'
  ['--balance']='_rig_volume_balance_values'
  ['-b']='_rig_volume_balance_values'
  ['--channel']='_rig_volume_channel_values'
  ['--channel-gain']='_rig_volume_channel_gain_values'
)

_rig_volume_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_volume_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_volume_flags[@]}" "${!_rig_volume_options[@]}"
      ;;
    *)
      _complete_rig_volume_positional "$current"
      ;;
  esac
}

_complete_rig_volume_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
    0)
      _mamba_filter "$current" 'output' 'input'
      ;;
  esac
}

# Describe simulated display brightness and visual properties.
# Inputs for brightness
_rig_brightness_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_brightness_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_brightness_level_values=(
)

_rig_brightness_gamma_values=(
)

_rig_brightness_temperature_values=(
)

_rig_brightness_contrast_values=(
)

_rig_brightness_display_values=(
)

declare -A _rig_brightness_options=(
  ['--format']='_rig_brightness_format_values'
  ['--level']='_rig_brightness_level_values'
  ['-l']='_rig_brightness_level_values'
  ['--gamma']='_rig_brightness_gamma_values'
  ['-g']='_rig_brightness_gamma_values'
  ['--temperature']='_rig_brightness_temperature_values'
  ['-t']='_rig_brightness_temperature_values'
  ['--contrast']='_rig_brightness_contrast_values'
  ['--display']='_rig_brightness_display_values'
  ['-d']='_rig_brightness_display_values'
)

_rig_brightness_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_brightness_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_brightness_flags[@]}" "${!_rig_brightness_options[@]}"
      ;;
    *)
      _complete_rig_brightness_positional "$current"
      ;;
  esac
}

_complete_rig_brightness_positional() {
  local current="$1"
}

# Describe a simulated workstation power action.
# Inputs for power
_rig_power_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '-f'
  '--force'
)

_rig_power_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_power_delay_values=(
)

_rig_power_reason_values=(
)

declare -A _rig_power_options=(
  ['--format']='_rig_power_format_values'
  ['--delay']='_rig_power_delay_values'
  ['-d']='_rig_power_delay_values'
  ['--reason']='_rig_power_reason_values'
  ['-r']='_rig_power_reason_values'
)

_rig_power_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_power_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_power_flags[@]}" "${!_rig_power_options[@]}"
      ;;
    *)
      _complete_rig_power_positional "$current"
      ;;
  esac
}

_complete_rig_power_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
    0)
      _mamba_filter "$current" 'lock' 'sleep' 'hibernate' 'restart' 'shutdown'
      ;;
  esac
}

# Describe simulated process inspection and control operations.
# Inputs for process
_rig_process_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_process_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_process_priority_values=(
)

_rig_process_pid_values=(
)

_rig_process_name_values=(
)

_rig_process_cpu_values=(
)

_rig_process_limit_cpu_percent_values=(
)

_rig_process_limit_memory_mb_values=(
)

_rig_process_limit_io_read_values=(
)

_rig_process_limit_io_write_values=(
)

declare -A _rig_process_options=(
  ['--format']='_rig_process_format_values'
  ['--priority']='_rig_process_priority_values'
  ['--pid']='_rig_process_pid_values'
  ['-p']='_rig_process_pid_values'
  ['--name']='_rig_process_name_values'
  ['-n']='_rig_process_name_values'
  ['--cpu']='_rig_process_cpu_values'
  ['-c']='_rig_process_cpu_values'
  ['--limit.cpu.percent']='_rig_process_limit_cpu_percent_values'
  ['--limit.memory.mb']='_rig_process_limit_memory_mb_values'
  ['--limit.io.read']='_rig_process_limit_io_read_values'
  ['--limit.io.write']='_rig_process_limit_io_write_values'
)

_rig_process_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_process_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_process_flags[@]}" "${!_rig_process_options[@]}"
      ;;
    *)
      _complete_rig_process_positional "$current"
      ;;
  esac
}

_complete_rig_process_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
    0)
      _mamba_filter "$current" 'inspect' 'limit' 'kill' 'priority'
      ;;
  esac
}

# Describe simulated cleanup of selected categories.
# Inputs for clean
_rig_clean_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '--include-hidden'
)

_rig_clean_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_clean_older_than_values=(
)

_rig_clean_larger_than_values=(
)

_rig_clean_exclude_values=(
)

declare -A _rig_clean_options=(
  ['--format']='_rig_clean_format_values'
  ['--older-than']='_rig_clean_older_than_values'
  ['--larger-than']='_rig_clean_larger_than_values'
  ['--exclude']='_rig_clean_exclude_values'
)

_rig_clean_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_clean_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_clean_flags[@]}" "${!_rig_clean_options[@]}"
      ;;
    *)
      _complete_rig_clean_positional "$current"
      ;;
  esac
}

_complete_rig_clean_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
    0|1|2|3|4|5)
      _mamba_filter "$current" 'cache' 'logs' 'temp' 'thumbnails' 'downloads' 'trash'
      ;;
  esac
}

# Generate a completion artifact without writing files.
#
# Print a generated completion artifact to standard output. The command
# never writes files; redirect its output explicitly if desired.
# Inputs for completion
_rig_completion_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_completion_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_completion_shell_values=(
  'carapace'
  'bash'
  'fish'
  'zsh'
  'powershell'
)

declare -A _rig_completion_options=(
  ['--format']='_rig_completion_format_values'
  ['--shell']='_rig_completion_shell_values'
)

_rig_completion_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_completion_format_values[@]}"
      return
      ;;
    --shell)
      _mamba_filter "$current" "${_rig_completion_shell_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_completion_flags[@]}" "${!_rig_completion_options[@]}"
      ;;
    *)
      _complete_rig_completion_positional "$current"
      ;;
  esac
}

_complete_rig_completion_positional() {
  local current="$1"
}

# Organize simulated networking commands; no traffic is sent.
# Inputs for network
_rig_network_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_network_options=(
  ['--format']='_rig_network_format_values'
)

# Describe simulated Wi-Fi operations.
# Inputs for network wifi
_rig_network_wifi_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_wifi_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_network_wifi_options=(
  ['--format']='_rig_network_wifi_format_values'
)

# Describe connecting to a simulated Wi-Fi network.
# Inputs for network wifi connect
_rig_network_wifi_connect_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '--hidden'
)

_rig_network_wifi_connect_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_wifi_connect_ssid_values=(
)

_rig_network_wifi_connect_password_values=(
)

_rig_network_wifi_connect_channel_values=(
)

declare -A _rig_network_wifi_connect_options=(
  ['--format']='_rig_network_wifi_connect_format_values'
  ['--ssid']='_rig_network_wifi_connect_ssid_values'
  ['--password']='_rig_network_wifi_connect_password_values'
  ['--channel']='_rig_network_wifi_connect_channel_values'
)

_rig_network_wifi_connect_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_wifi_connect_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_wifi_connect_flags[@]}" "${!_rig_network_wifi_connect_options[@]}"
      ;;
    *)
      _complete_rig_network_wifi_connect_positional "$current"
      ;;
  esac
}

_complete_rig_network_wifi_connect_positional() {
  local current="$1"
}

# Describe disconnecting from a simulated Wi-Fi network.
# Inputs for network wifi disconnect
_rig_network_wifi_disconnect_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_wifi_disconnect_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_wifi_disconnect_ssid_values=(
)

declare -A _rig_network_wifi_disconnect_options=(
  ['--format']='_rig_network_wifi_disconnect_format_values'
  ['--ssid']='_rig_network_wifi_disconnect_ssid_values'
)

_rig_network_wifi_disconnect_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_wifi_disconnect_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_wifi_disconnect_flags[@]}" "${!_rig_network_wifi_disconnect_options[@]}"
      ;;
    *)
      _complete_rig_network_wifi_disconnect_positional "$current"
      ;;
  esac
}

_complete_rig_network_wifi_disconnect_positional() {
  local current="$1"
}

# Describe scanning simulated Wi-Fi results.
# Inputs for network wifi scan
_rig_network_wifi_scan_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '--hidden'
)

_rig_network_wifi_scan_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_wifi_scan_channel_values=(
)

declare -A _rig_network_wifi_scan_options=(
  ['--format']='_rig_network_wifi_scan_format_values'
  ['--channel']='_rig_network_wifi_scan_channel_values'
)

_rig_network_wifi_scan_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_wifi_scan_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_wifi_scan_flags[@]}" "${!_rig_network_wifi_scan_options[@]}"
      ;;
    *)
      _complete_rig_network_wifi_scan_positional "$current"
      ;;
  esac
}

_complete_rig_network_wifi_scan_positional() {
  local current="$1"
}

# Describe simulated Wi-Fi status.
# Inputs for network wifi status
_rig_network_wifi_status_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_wifi_status_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_network_wifi_status_options=(
  ['--format']='_rig_network_wifi_status_format_values'
)

_rig_network_wifi_status_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_wifi_status_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_wifi_status_flags[@]}" "${!_rig_network_wifi_status_options[@]}"
      ;;
    *)
      _complete_rig_network_wifi_status_positional "$current"
      ;;
  esac
}

_complete_rig_network_wifi_status_positional() {
  local current="$1"
}

_rig_network_wifi_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_wifi_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_wifi_flags[@]}" "${!_rig_network_wifi_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'connect' 'disconnect' 'scan' 'status'
      _complete_rig_network_wifi_positional "$current"
      ;;
  esac
}

_complete_rig_network_wifi_positional() {
  local current="$1"
}

# Describe simulated DNS configuration.
# Inputs for network dns
_rig_network_dns_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_dns_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_network_dns_options=(
  ['--format']='_rig_network_dns_format_values'
)

# Show fixed simulated DNS configuration.
# Inputs for network dns get
_rig_network_dns_get_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_dns_get_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_dns_get_interface_values=(
)

declare -A _rig_network_dns_get_options=(
  ['--format']='_rig_network_dns_get_format_values'
  ['--interface']='_rig_network_dns_get_interface_values'
)

_rig_network_dns_get_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_dns_get_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_dns_get_flags[@]}" "${!_rig_network_dns_get_options[@]}"
      ;;
    *)
      _complete_rig_network_dns_get_positional "$current"
      ;;
  esac
}

_complete_rig_network_dns_get_positional() {
  local current="$1"
}

# Describe configuring simulated DNS servers.
# Inputs for network dns set
_rig_network_dns_set_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_dns_set_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_dns_set_interface_values=(
)

_rig_network_dns_set_server_values=(
)

declare -A _rig_network_dns_set_options=(
  ['--format']='_rig_network_dns_set_format_values'
  ['--interface']='_rig_network_dns_set_interface_values'
  ['--server']='_rig_network_dns_set_server_values'
)

_rig_network_dns_set_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_dns_set_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_dns_set_flags[@]}" "${!_rig_network_dns_set_options[@]}"
      ;;
    *)
      _complete_rig_network_dns_set_positional "$current"
      ;;
  esac
}

_complete_rig_network_dns_set_positional() {
  local current="$1"
}

# Describe restoring simulated DNS defaults.
# Inputs for network dns reset
_rig_network_dns_reset_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_dns_reset_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_dns_reset_interface_values=(
)

declare -A _rig_network_dns_reset_options=(
  ['--format']='_rig_network_dns_reset_format_values'
  ['--interface']='_rig_network_dns_reset_interface_values'
)

_rig_network_dns_reset_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_dns_reset_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_dns_reset_flags[@]}" "${!_rig_network_dns_reset_options[@]}"
      ;;
    *)
      _complete_rig_network_dns_reset_positional "$current"
      ;;
  esac
}

_complete_rig_network_dns_reset_positional() {
  local current="$1"
}

_rig_network_dns_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_dns_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_dns_flags[@]}" "${!_rig_network_dns_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'get' 'set' 'reset'
      _complete_rig_network_dns_positional "$current"
      ;;
  esac
}

_complete_rig_network_dns_positional() {
  local current="$1"
}

# Describe simulated HTTP, HTTPS, and SOCKS proxy settings.
# Inputs for network proxy
_rig_network_proxy_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_proxy_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_proxy_http_host_values=(
)

_rig_network_proxy_http_port_values=(
)

_rig_network_proxy_https_host_values=(
)

_rig_network_proxy_https_port_values=(
)

_rig_network_proxy_socks_host_values=(
)

_rig_network_proxy_socks_port_values=(
)

declare -A _rig_network_proxy_options=(
  ['--format']='_rig_network_proxy_format_values'
  ['--http.host']='_rig_network_proxy_http_host_values'
  ['--http.port']='_rig_network_proxy_http_port_values'
  ['--https.host']='_rig_network_proxy_https_host_values'
  ['--https.port']='_rig_network_proxy_https_port_values'
  ['--socks.host']='_rig_network_proxy_socks_host_values'
  ['--socks.port']='_rig_network_proxy_socks_port_values'
)

_rig_network_proxy_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_proxy_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_proxy_flags[@]}" "${!_rig_network_proxy_options[@]}"
      ;;
    *)
      _complete_rig_network_proxy_positional "$current"
      ;;
  esac
}

_complete_rig_network_proxy_positional() {
  local current="$1"
}

# Describe mock connectivity measurements without sending traffic.
# Inputs for network ping
_rig_network_ping_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_network_ping_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_network_ping_count_values=(
)

_rig_network_ping_timeout_values=(
)

declare -A _rig_network_ping_options=(
  ['--format']='_rig_network_ping_format_values'
  ['--count']='_rig_network_ping_count_values'
  ['--timeout']='_rig_network_ping_timeout_values'
)

_rig_network_ping_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_ping_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_ping_flags[@]}" "${!_rig_network_ping_options[@]}"
      ;;
    *)
      _complete_rig_network_ping_positional "$current"
      ;;
  esac
}

_complete_rig_network_ping_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

_rig_network_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_network_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_network_flags[@]}" "${!_rig_network_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'wifi' 'dns' 'proxy' 'ping'
      _complete_rig_network_positional "$current"
      ;;
  esac
}

_complete_rig_network_positional() {
  local current="$1"
}

# Manage reusable simulated workstation configurations.
# Inputs for profile
_rig_profile_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_profile_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_profile_options=(
  ['--format']='_rig_profile_format_values'
)

# Describe saving the current simulated configuration.
# Inputs for profile save
_rig_profile_save_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_profile_save_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_profile_save_options=(
  ['--format']='_rig_profile_save_format_values'
)

_rig_profile_save_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_profile_save_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_profile_save_flags[@]}" "${!_rig_profile_save_options[@]}"
      ;;
    *)
      _complete_rig_profile_save_positional "$current"
      ;;
  esac
}

_complete_rig_profile_save_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

# Describe applying a simulated profile.
# Inputs for profile apply
_rig_profile_apply_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '--force'
)

_rig_profile_apply_format_values=(
  'text'
  'json'
  'yaml'
)

_rig_profile_apply_only_values=(
)

_rig_profile_apply_except_values=(
)

declare -A _rig_profile_apply_options=(
  ['--format']='_rig_profile_apply_format_values'
  ['--only']='_rig_profile_apply_only_values'
  ['--except']='_rig_profile_apply_except_values'
)

_rig_profile_apply_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_profile_apply_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_profile_apply_flags[@]}" "${!_rig_profile_apply_options[@]}"
      ;;
    *)
      _complete_rig_profile_apply_positional "$current"
      ;;
  esac
}

_complete_rig_profile_apply_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

# Describe removing an in-memory simulated profile.
# Inputs for profile remove
_rig_profile_remove_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
  '-f'
  '--force'
)

_rig_profile_remove_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_profile_remove_options=(
  ['--format']='_rig_profile_remove_format_values'
)

_rig_profile_remove_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_profile_remove_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_profile_remove_flags[@]}" "${!_rig_profile_remove_options[@]}"
      ;;
    *)
      _complete_rig_profile_remove_positional "$current"
      ;;
  esac
}

_complete_rig_profile_remove_positional() {
  local current="$1"
  local index=$_mamba_positional_index
  case "$index" in
  esac
}

# List fixed in-memory simulated profiles.
# Inputs for profile list
_rig_profile_list_flags=(
  '-h'
  '--help'
  '--dry-run'
  '-v'
  '--verbose'
)

_rig_profile_list_format_values=(
  'text'
  'json'
  'yaml'
)

declare -A _rig_profile_list_options=(
  ['--format']='_rig_profile_list_format_values'
)

_rig_profile_list_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_profile_list_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_profile_list_flags[@]}" "${!_rig_profile_list_options[@]}"
      ;;
    *)
      _complete_rig_profile_list_positional "$current"
      ;;
  esac
}

_complete_rig_profile_list_positional() {
  local current="$1"
}

_rig_profile_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --format)
      _mamba_filter "$current" "${_rig_profile_format_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_profile_flags[@]}" "${!_rig_profile_options[@]}"
      ;;
    *)
      _mamba_filter "$current" 'save' 'apply' 'remove' 'list'
      _complete_rig_profile_positional "$current"
      ;;
  esac
}

_complete_rig_profile_positional() {
  local current="$1"
}

_rig_root_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

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
      _mamba_filter "$current" 'volume' 'vol' 'brightness' 'bright' 'power' 'pwr' 'process' 'proc' 'clean' 'sweep' 'completion' 'network' 'net' 'profile' 'preset'
      _complete_rig_positional "$current"
      ;;
  esac
}

_complete_rig_positional() {
  local current="$1"
}

_rig_completion() {
  local path='rig'
  local handler='_rig_root_completion'
  local index token route
  local positional_index=0

  for ((index = 1; index < COMP_CWORD; index++)); do
    token="${COMP_WORDS[index]}"
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

  _mamba_positional_index=$positional_index
  "$handler"
}

complete -F _rig_completion rig
