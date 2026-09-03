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
  '-n'
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

# Describe simulated audio input and output operations.
# Inputs for volume
_rig_volume_flags=(
  '-h'
  '--help'
  '-m'
  '--mute'
  '-u'
  '--unmute'
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_volume_flags[@]}" "${!_rig_options[@]}" "${!_rig_volume_options[@]}"
      ;;
    *)
      _complete_rig_volume_positional "$current"
      ;;
  esac
}

_complete_rig_volume_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_brightness_flags[@]}" "${!_rig_options[@]}" "${!_rig_brightness_options[@]}"
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
  '-f'
  '--force'
)

_rig_power_delay_values=(
)

_rig_power_reason_values=(
)

declare -A _rig_power_options=(
  ['--delay']='_rig_power_delay_values'
  ['-d']='_rig_power_delay_values'
  ['--reason']='_rig_power_reason_values'
  ['-r']='_rig_power_reason_values'
)

_rig_power_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_power_flags[@]}" "${!_rig_options[@]}" "${!_rig_power_options[@]}"
      ;;
    *)
      _complete_rig_power_positional "$current"
      ;;
  esac
}

_complete_rig_power_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_process_flags[@]}" "${!_rig_options[@]}" "${!_rig_process_options[@]}"
      ;;
    *)
      _complete_rig_process_positional "$current"
      ;;
  esac
}

_complete_rig_process_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
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
  '--include-hidden'
)

_rig_clean_older_than_values=(
)

_rig_clean_larger_than_values=(
)

_rig_clean_exclude_values=(
)

declare -A _rig_clean_options=(
  ['--older-than']='_rig_clean_older_than_values'
  ['--larger-than']='_rig_clean_larger_than_values'
  ['--exclude']='_rig_clean_exclude_values'
)

_rig_clean_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_clean_flags[@]}" "${!_rig_options[@]}" "${!_rig_clean_options[@]}"
      ;;
    *)
      _complete_rig_clean_positional "$current"
      ;;
  esac
}

_complete_rig_clean_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
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
)

_rig_completion_shell_values=(
  'carapace'
  'bash'
  'fish'
  'zsh'
  'powershell'
)

declare -A _rig_completion_options=(
  ['--shell']='_rig_completion_shell_values'
)

_rig_completion_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
    --shell)
      _mamba_filter "$current" "${_rig_completion_shell_values[@]}"
      return
      ;;
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_completion_flags[@]}" "${!_rig_options[@]}" "${!_rig_completion_options[@]}"
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
)

declare -A _rig_network_options=(
)

# Describe simulated Wi-Fi operations.
# Inputs for network wifi
_rig_network_wifi_flags=(
  '-h'
  '--help'
)

declare -A _rig_network_wifi_options=(
)

# Describe connecting to a simulated Wi-Fi network.
# Inputs for network wifi connect
_rig_network_wifi_connect_flags=(
  '-h'
  '--help'
  '--hidden'
)

_rig_network_wifi_connect_ssid_values=(
)

_rig_network_wifi_connect_password_values=(
)

_rig_network_wifi_connect_channel_values=(
)

declare -A _rig_network_wifi_connect_options=(
  ['--ssid']='_rig_network_wifi_connect_ssid_values'
  ['--password']='_rig_network_wifi_connect_password_values'
  ['--channel']='_rig_network_wifi_connect_channel_values'
)

_rig_network_wifi_connect_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_wifi_connect_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_wifi_connect_options[@]}"
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
)

_rig_network_wifi_disconnect_ssid_values=(
)

declare -A _rig_network_wifi_disconnect_options=(
  ['--ssid']='_rig_network_wifi_disconnect_ssid_values'
)

_rig_network_wifi_disconnect_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_wifi_disconnect_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_wifi_disconnect_options[@]}"
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
  '--hidden'
)

_rig_network_wifi_scan_channel_values=(
)

declare -A _rig_network_wifi_scan_options=(
  ['--channel']='_rig_network_wifi_scan_channel_values'
)

_rig_network_wifi_scan_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_wifi_scan_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_wifi_scan_options[@]}"
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
)

declare -A _rig_network_wifi_status_options=(
)

_rig_network_wifi_status_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_wifi_status_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_wifi_status_options[@]}"
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_wifi_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_wifi_options[@]}"
      ;;
    *)
      case "$current" in
      connect)
        _rig_network_wifi_connect_completion
        ;;
      disconnect)
        _rig_network_wifi_disconnect_completion
        ;;
      scan)
        _rig_network_wifi_scan_completion
        ;;
      status)
        _rig_network_wifi_status_completion
        ;;
      *)
        _mamba_filter "$current" 'connect' 'disconnect' 'scan' 'status'
        ;;
      esac
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
)

declare -A _rig_network_dns_options=(
)

# Show fixed simulated DNS configuration.
# Inputs for network dns get
_rig_network_dns_get_flags=(
  '-h'
  '--help'
)

_rig_network_dns_get_interface_values=(
)

declare -A _rig_network_dns_get_options=(
  ['--interface']='_rig_network_dns_get_interface_values'
)

_rig_network_dns_get_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_dns_get_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_dns_get_options[@]}"
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
)

_rig_network_dns_set_interface_values=(
)

_rig_network_dns_set_server_values=(
)

declare -A _rig_network_dns_set_options=(
  ['--interface']='_rig_network_dns_set_interface_values'
  ['--server']='_rig_network_dns_set_server_values'
)

_rig_network_dns_set_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_dns_set_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_dns_set_options[@]}"
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
)

_rig_network_dns_reset_interface_values=(
)

declare -A _rig_network_dns_reset_options=(
  ['--interface']='_rig_network_dns_reset_interface_values'
)

_rig_network_dns_reset_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_dns_reset_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_dns_reset_options[@]}"
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_dns_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_dns_options[@]}"
      ;;
    *)
      case "$current" in
      get)
        _rig_network_dns_get_completion
        ;;
      set)
        _rig_network_dns_set_completion
        ;;
      reset)
        _rig_network_dns_reset_completion
        ;;
      *)
        _mamba_filter "$current" 'get' 'set' 'reset'
        ;;
      esac
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_proxy_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_proxy_options[@]}"
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
)

_rig_network_ping_count_values=(
)

_rig_network_ping_timeout_values=(
)

declare -A _rig_network_ping_options=(
  ['--count']='_rig_network_ping_count_values'
  ['--timeout']='_rig_network_ping_timeout_values'
)

_rig_network_ping_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_ping_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_ping_options[@]}"
      ;;
    *)
      _complete_rig_network_ping_positional "$current"
      ;;
  esac
}

_complete_rig_network_ping_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
  case "$index" in
  esac
}

_rig_network_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_network_flags[@]}" "${!_rig_options[@]}" "${!_rig_network_options[@]}"
      ;;
    *)
      case "$current" in
      wifi)
        _rig_network_wifi_completion
        ;;
      dns)
        _rig_network_dns_completion
        ;;
      proxy)
        _rig_network_proxy_completion
        ;;
      ping)
        _rig_network_ping_completion
        ;;
      *)
        _mamba_filter "$current" 'wifi' 'dns' 'proxy' 'ping'
        ;;
      esac
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
)

declare -A _rig_profile_options=(
)

# Describe saving the current simulated configuration.
# Inputs for profile save
_rig_profile_save_flags=(
  '-h'
  '--help'
)

declare -A _rig_profile_save_options=(
)

_rig_profile_save_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_profile_save_flags[@]}" "${!_rig_options[@]}" "${!_rig_profile_save_options[@]}"
      ;;
    *)
      _complete_rig_profile_save_positional "$current"
      ;;
  esac
}

_complete_rig_profile_save_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
  case "$index" in
  esac
}

# Describe applying a simulated profile.
# Inputs for profile apply
_rig_profile_apply_flags=(
  '-h'
  '--help'
  '--force'
)

_rig_profile_apply_only_values=(
)

_rig_profile_apply_except_values=(
)

declare -A _rig_profile_apply_options=(
  ['--only']='_rig_profile_apply_only_values'
  ['--except']='_rig_profile_apply_except_values'
)

_rig_profile_apply_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_profile_apply_flags[@]}" "${!_rig_options[@]}" "${!_rig_profile_apply_options[@]}"
      ;;
    *)
      _complete_rig_profile_apply_positional "$current"
      ;;
  esac
}

_complete_rig_profile_apply_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
  case "$index" in
  esac
}

# Describe removing an in-memory simulated profile.
# Inputs for profile remove
_rig_profile_remove_flags=(
  '-h'
  '--help'
  '-f'
  '--force'
)

declare -A _rig_profile_remove_options=(
)

_rig_profile_remove_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_profile_remove_flags[@]}" "${!_rig_options[@]}" "${!_rig_profile_remove_options[@]}"
      ;;
    *)
      _complete_rig_profile_remove_positional "$current"
      ;;
  esac
}

_complete_rig_profile_remove_positional() {
  local current="$1"
  local index=$((COMP_CWORD - 1))
  case "$index" in
  esac
}

# List fixed in-memory simulated profiles.
# Inputs for profile list
_rig_profile_list_flags=(
  '-h'
  '--help'
)

declare -A _rig_profile_list_options=(
)

_rig_profile_list_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]}"

  case "$previous" in
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_profile_list_flags[@]}" "${!_rig_options[@]}" "${!_rig_profile_list_options[@]}"
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
  esac

  case "$current" in
    -*)
      _mamba_filter "$current" "${_rig_flags[@]}" "${_rig_profile_flags[@]}" "${!_rig_options[@]}" "${!_rig_profile_options[@]}"
      ;;
    *)
      case "$current" in
      save)
        _rig_profile_save_completion
        ;;
      apply)
        _rig_profile_apply_completion
        ;;
      remove)
        _rig_profile_remove_completion
        ;;
      list)
        _rig_profile_list_completion
        ;;
      *)
        _mamba_filter "$current" 'save' 'apply' 'remove' 'list'
        ;;
      esac
      _complete_rig_profile_positional "$current"
      ;;
  esac
}

_complete_rig_profile_positional() {
  local current="$1"
}

_rig_completion() {
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
      case "$current" in
      volume|vol)
        _rig_volume_completion
        ;;
      brightness|bright)
        _rig_brightness_completion
        ;;
      power|pwr)
        _rig_power_completion
        ;;
      process|proc)
        _rig_process_completion
        ;;
      clean|sweep)
        _rig_clean_completion
        ;;
      completion)
        _rig_completion_completion
        ;;
      network|net)
        _rig_network_completion
        ;;
      profile|preset)
        _rig_profile_completion
        ;;
      *)
        _mamba_filter "$current" 'volume' 'vol' 'brightness' 'bright' 'power' 'pwr' 'process' 'proc' 'clean' 'sweep' 'completion' 'network' 'net' 'profile' 'preset'
        ;;
      esac
      _complete_rig_positional "$current"
      ;;
  esac
}

_complete_rig_positional() {
  local current="$1"
}

complete -F _rig_completion rig
