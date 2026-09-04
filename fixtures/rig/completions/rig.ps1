<#
 PowerShell completion for rig.
 Generated; do not edit by hand.

 A mock workstation-control CLI for harmless terminal simulations.

 rig only prints simulated operations. It never changes, inspects,
 connects to, or otherwise affects the computer.
#>
$script:MambaRigNativeCommands = @{
    'root' = 'root'
    'volume' = 'volume'
    'vol' = 'volume'
    'brightness' = 'brightness'
    'bright' = 'brightness'
    'power' = 'power'
    'pwr' = 'power'
    'process' = 'process'
    'proc' = 'process'
    'clean' = 'clean'
    'sweep' = 'clean'
    'completion' = 'completion'
    'network' = 'network'
    'net' = 'network'
    'wifi' = 'wifi'
    'connect' = 'connect'
    'disconnect' = 'disconnect'
    'scan' = 'scan'
    'status' = 'status'
    'dns' = 'dns'
    'get' = 'get'
    'set' = 'set'
    'reset' = 'reset'
    'proxy' = 'proxy'
    'ping' = 'ping'
    'profile' = 'profile'
    'preset' = 'profile'
    'save' = 'save'
    'apply' = 'apply'
    'remove' = 'remove'
    'list' = 'list'
}

$script:MambaRigInputs = @{}
$script:MambaRigChildren = @{}
$script:MambaRigPositionalSlots = @{}
$script:MambaRigValueHandlers = @{}
$script:MambaRigVariadicHandlers = @{}

$script:MambaRigInputs['root'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root'] = @(
    [PSCustomObject]@{ Name = 'volume'; Description = 'Describe simulated audio input and output operations.' }
    [PSCustomObject]@{ Name = 'vol'; Description = 'Alias for volume. Describe simulated audio input and output operations.' }
    [PSCustomObject]@{ Name = 'brightness'; Description = 'Describe simulated display brightness and visual properties.' }
    [PSCustomObject]@{ Name = 'bright'; Description = 'Alias for brightness. Describe simulated display brightness and visual properties.' }
    [PSCustomObject]@{ Name = 'power'; Description = 'Describe a simulated workstation power action.' }
    [PSCustomObject]@{ Name = 'pwr'; Description = 'Alias for power. Describe a simulated workstation power action.' }
    [PSCustomObject]@{ Name = 'process'; Description = 'Describe simulated process inspection and control operations.' }
    [PSCustomObject]@{ Name = 'proc'; Description = 'Alias for process. Describe simulated process inspection and control operations.' }
    [PSCustomObject]@{ Name = 'clean'; Description = 'Describe simulated cleanup of selected categories.' }
    [PSCustomObject]@{ Name = 'sweep'; Description = 'Alias for clean. Describe simulated cleanup of selected categories.' }
    [PSCustomObject]@{ Name = 'completion'; Description = 'Generate a completion artifact without writing files.' }
    [PSCustomObject]@{ Name = 'network'; Description = 'Organize simulated networking commands; no traffic is sent.' }
    [PSCustomObject]@{ Name = 'net'; Description = 'Alias for network. Organize simulated networking commands; no traffic is sent.' }
    [PSCustomObject]@{ Name = 'profile'; Description = 'Manage reusable simulated workstation configurations.' }
    [PSCustomObject]@{ Name = 'preset'; Description = 'Alias for profile. Manage reusable simulated workstation configurations.' }
    )
$script:MambaRigPositionalSlots['root'] = @{}
$script:MambaRigValueHandlers['root.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.volume'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--mute'; Description = 'Mute the simulated target.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-m'; Description = 'Mute the simulated target.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--unmute'; Description = 'Unmute the simulated target.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-u'; Description = 'Unmute the simulated target.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--device'; Description = 'Simulated audio device name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-d'; Description = 'Simulated audio device name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--level'; Description = 'Simulated volume level, from 0 through 100.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-l'; Description = 'Simulated volume level, from 0 through 100.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--balance'; Description = 'Simulated stereo balance, from -1.0 through 1.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-b'; Description = 'Simulated stereo balance, from -1.0 through 1.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--channel'; Description = 'Repeatable simulated audio channel name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--channel-gain'; Description = 'Repeatable channel gain, from 0.0 through 2.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.volume'] = @(
    )
$script:MambaRigPositionalSlots['root.volume'] = @{
    0 = [PSCustomObject]@{ Choices = @('output', 'input'); Description = 'Simulated audio target.' }
    }
$script:MambaRigValueHandlers['root.volume.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.brightness'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--level'; Description = 'Brightness percentage, from 0 through 100.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-l'; Description = 'Brightness percentage, from 0 through 100.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--gamma'; Description = 'Display gamma, from 0.5 through 3.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-g'; Description = 'Display gamma, from 0.5 through 3.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--temperature'; Description = 'Color temperature in simulated Kelvin.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-t'; Description = 'Color temperature in simulated Kelvin.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--contrast'; Description = 'Contrast multiplier, from 0.0 through 2.0.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--display'; Description = 'Repeatable simulated display name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-d'; Description = 'Repeatable simulated display name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.brightness'] = @(
    )
$script:MambaRigPositionalSlots['root.brightness'] = @{}
$script:MambaRigValueHandlers['root.brightness.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.power'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--force'; Description = 'Describe simulated force behavior without bypassing safety.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-f'; Description = 'Describe simulated force behavior without bypassing safety.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--delay'; Description = 'Non-negative simulated delay in seconds.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-d'; Description = 'Non-negative simulated delay in seconds.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--reason'; Description = 'Human-readable simulated reason.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-r'; Description = 'Human-readable simulated reason.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.power'] = @(
    )
$script:MambaRigPositionalSlots['root.power'] = @{
    0 = [PSCustomObject]@{ Choices = @('lock', 'sleep', 'hibernate', 'restart', 'shutdown'); Description = 'Simulated power action.' }
    }
$script:MambaRigValueHandlers['root.power.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.process'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--priority'; Description = 'Simulated process priority for the priority action.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--pid'; Description = 'Repeatable simulated process ID.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-p'; Description = 'Repeatable simulated process ID.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--name'; Description = 'Repeatable simulated process name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-n'; Description = 'Repeatable simulated process name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--cpu'; Description = 'Repeatable simulated CPU index.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-c'; Description = 'Repeatable simulated CPU index.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--limit.cpu.percent'; Description = 'CPU percentage from 0 through 100.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--limit.memory.mb'; Description = 'Memory limit in MB.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--limit.io.read'; Description = 'Read limit in MB/s.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--limit.io.write'; Description = 'Write limit in MB/s.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    )
$script:MambaRigChildren['root.process'] = @(
    )
$script:MambaRigPositionalSlots['root.process'] = @{
    0 = [PSCustomObject]@{ Choices = @('inspect', 'limit', 'kill', 'priority'); Description = 'Simulated process action.' }
    }
$script:MambaRigValueHandlers['root.process.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.clean'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--include-hidden'; Description = 'Include simulated hidden items in the description.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--older-than'; Description = 'Age filter in non-negative days.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--larger-than'; Description = 'Size threshold in non-negative MB.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--exclude'; Description = 'Repeatable simulated category, path, or pattern exclusion.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.clean'] = @(
    )
$script:MambaRigPositionalSlots['root.clean'] = @{
    0 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    1 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    2 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    3 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    4 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    5 = [PSCustomObject]@{ Choices = @('cache', 'logs', 'temp', 'thumbnails', 'downloads', 'trash'); Description = 'One or more simulated cleanup targets.' }
    }
$script:MambaRigValueHandlers['root.clean.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.completion'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--shell'; Description = 'Completion artifact format to print to stdout.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.completion'] = @(
    )
$script:MambaRigPositionalSlots['root.completion'] = @{}
$script:MambaRigValueHandlers['root.completion.--format'] = @('text', 'json', 'yaml')
$script:MambaRigValueHandlers['root.completion.--shell'] = @('carapace', 'bash', 'fish', 'zsh', 'powershell')
$script:MambaRigInputs['root.network'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network'] = @(
    [PSCustomObject]@{ Name = 'wifi'; Description = 'Describe simulated Wi-Fi operations.' }
    [PSCustomObject]@{ Name = 'dns'; Description = 'Describe simulated DNS configuration.' }
    [PSCustomObject]@{ Name = 'proxy'; Description = 'Describe simulated HTTP, HTTPS, and SOCKS proxy settings.' }
    [PSCustomObject]@{ Name = 'ping'; Description = 'Describe mock connectivity measurements without sending traffic.' }
    )
$script:MambaRigPositionalSlots['root.network'] = @{}
$script:MambaRigValueHandlers['root.network.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.wifi'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.wifi'] = @(
    [PSCustomObject]@{ Name = 'connect'; Description = 'Describe connecting to a simulated Wi-Fi network.' }
    [PSCustomObject]@{ Name = 'disconnect'; Description = 'Describe disconnecting from a simulated Wi-Fi network.' }
    [PSCustomObject]@{ Name = 'scan'; Description = 'Describe scanning simulated Wi-Fi results.' }
    [PSCustomObject]@{ Name = 'status'; Description = 'Describe simulated Wi-Fi status.' }
    )
$script:MambaRigPositionalSlots['root.network.wifi'] = @{}
$script:MambaRigValueHandlers['root.network.wifi.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.wifi.connect'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--hidden'; Description = 'Describe a hidden simulated network.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--ssid'; Description = 'Simulated network name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--password'; Description = 'Masked simulated password; it is never printed.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--channel'; Description = 'Simulated Wi-Fi channel.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.wifi.connect'] = @(
    )
$script:MambaRigPositionalSlots['root.network.wifi.connect'] = @{}
$script:MambaRigValueHandlers['root.network.wifi.connect.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.wifi.disconnect'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--ssid'; Description = 'Optional simulated network name.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.wifi.disconnect'] = @(
    )
$script:MambaRigPositionalSlots['root.network.wifi.disconnect'] = @{}
$script:MambaRigValueHandlers['root.network.wifi.disconnect.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.wifi.scan'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--hidden'; Description = 'Include hidden simulated networks.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--channel'; Description = 'Optional simulated channel filter.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.wifi.scan'] = @(
    )
$script:MambaRigPositionalSlots['root.network.wifi.scan'] = @{}
$script:MambaRigValueHandlers['root.network.wifi.scan.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.wifi.status'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.wifi.status'] = @(
    )
$script:MambaRigPositionalSlots['root.network.wifi.status'] = @{}
$script:MambaRigValueHandlers['root.network.wifi.status.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.dns'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.dns'] = @(
    [PSCustomObject]@{ Name = 'get'; Description = 'Show fixed simulated DNS configuration.' }
    [PSCustomObject]@{ Name = 'set'; Description = 'Describe configuring simulated DNS servers.' }
    [PSCustomObject]@{ Name = 'reset'; Description = 'Describe restoring simulated DNS defaults.' }
    )
$script:MambaRigPositionalSlots['root.network.dns'] = @{}
$script:MambaRigValueHandlers['root.network.dns.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.dns.get'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--interface'; Description = 'Simulated network interface.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.dns.get'] = @(
    )
$script:MambaRigPositionalSlots['root.network.dns.get'] = @{}
$script:MambaRigValueHandlers['root.network.dns.get.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.dns.set'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--interface'; Description = 'Simulated network interface.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--server'; Description = 'Repeatable simulated DNS server in preserved order.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.dns.set'] = @(
    )
$script:MambaRigPositionalSlots['root.network.dns.set'] = @{}
$script:MambaRigValueHandlers['root.network.dns.set.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.dns.reset'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--interface'; Description = 'Simulated network interface.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.dns.reset'] = @(
    )
$script:MambaRigPositionalSlots['root.network.dns.reset'] = @{}
$script:MambaRigValueHandlers['root.network.dns.reset.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.proxy'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--http.host'; Description = 'HTTP proxy host.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--http.port'; Description = 'HTTP TCP port.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--https.host'; Description = 'HTTPS proxy host.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--https.port'; Description = 'HTTPS TCP port.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--socks.host'; Description = 'SOCKS proxy host.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--socks.port'; Description = 'SOCKS TCP port.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.proxy'] = @(
    )
$script:MambaRigPositionalSlots['root.network.proxy'] = @{}
$script:MambaRigValueHandlers['root.network.proxy.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.network.ping'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--count'; Description = 'Positive number of simulated requests.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--timeout'; Description = 'Positive simulated timeout in seconds.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.network.ping'] = @(
    )
$script:MambaRigPositionalSlots['root.network.ping'] = @{
    }
$script:MambaRigValueHandlers['root.network.ping.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.profile'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.profile'] = @(
    [PSCustomObject]@{ Name = 'save'; Description = 'Describe saving the current simulated configuration.' }
    [PSCustomObject]@{ Name = 'apply'; Description = 'Describe applying a simulated profile.' }
    [PSCustomObject]@{ Name = 'remove'; Description = 'Describe removing an in-memory simulated profile.' }
    [PSCustomObject]@{ Name = 'list'; Description = 'List fixed in-memory simulated profiles.' }
    )
$script:MambaRigPositionalSlots['root.profile'] = @{}
$script:MambaRigValueHandlers['root.profile.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.profile.save'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.profile.save'] = @(
    )
$script:MambaRigPositionalSlots['root.profile.save'] = @{
    }
$script:MambaRigValueHandlers['root.profile.save.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.profile.apply'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--force'; Description = 'Describe simulated force behavior without bypassing safety.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--only'; Description = 'Repeatable simulated section to include.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--except'; Description = 'Repeatable simulated section to exclude.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.profile.apply'] = @(
    )
$script:MambaRigPositionalSlots['root.profile.apply'] = @{
    }
$script:MambaRigValueHandlers['root.profile.apply.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.profile.remove'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--force'; Description = 'Confirm simulated profile removal.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-f'; Description = 'Confirm simulated profile removal.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.profile.remove'] = @(
    )
$script:MambaRigPositionalSlots['root.profile.remove'] = @{
    }
$script:MambaRigValueHandlers['root.profile.remove.--format'] = @('text', 'json', 'yaml')
$script:MambaRigInputs['root.profile.list'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Show what would happen without changing anything.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-v'; Description = 'Increase output verbosity.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Simulated output format: text, json, or yaml.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root.profile.list'] = @(
    )
$script:MambaRigPositionalSlots['root.profile.list'] = @{}
$script:MambaRigValueHandlers['root.profile.list.--format'] = @('text', 'json', 'yaml')
function Update-MambaRigStateObject {
    param(
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$Element
    )
    $extent = $Element.Extent
    if ($null -eq $extent) { return $false }
    if ($extent.StartOffset -ge $CursorPosition) { return $false }
    if ($extent.EndOffset -gt $CursorPosition) { return $false }
    return $true
}

function Find-MambaRigInput {
    param(
        [Parameter(Mandatory)][string]$PathKey,
        [Parameter(Mandatory)][string]$Spelling
    )
    $inputs = $script:MambaRigInputs[$PathKey]
    if ($null -eq $inputs) { return $null }
    foreach ($input in $inputs) {
        if ($input.Spelling -ceq $Spelling) { return $input }
    }
    return $null
}

function Resolve-MambaRigState {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$WordToComplete,
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$CommandAst
    )
    $resolved = @('root')
    $pendingValueOwner = $null
    $afterDoubleDash = $false
    $positionalIndex = -1
    $usedNonRepeatable = @{}
    $elements = @($CommandAst.CommandElements)
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if (-not (Update-MambaRigStateObject -CursorPosition $CursorPosition -Element $el)) { continue }
        $isLastElement = ($i -eq $elements.Count - 1)
        $tokenText = $el.Extent.Text
        # The last AST element is the completion word only while the cursor
        # is inside it or immediately after it; a trailing space means the
        # last element has already been supplied.
        $isWord = $isLastElement -and ($el.Extent.EndOffset -ge $CursorPosition)

        if ($isWord) { continue }

        # A value belongs to the preceding option even when it looks like a
        # command, another option, or the variadic separator.
        if ($null -ne $pendingValueOwner) {
            $usedNonRepeatable[$pendingValueOwner] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($afterDoubleDash) {
            $positionalIndex = $positionalIndex + 1
            continue
        }

        if ($tokenText -eq '--') {
            $afterDoubleDash = $true
            continue
        }

        $pathKey = $resolved -join '.'
        $children = @($script:MambaRigChildren[$pathKey])
        $canonical = $null
        foreach ($child in $children) {
            if ($child.Name -ceq $tokenText) {
                $canonical = $script:MambaRigNativeCommands[$child.Name]
                break
            }
        }
        if ($null -ne $canonical) {
            $resolved += ,$canonical
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('--', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 2) {
            $tail = $tokenText.Substring(2)
            if ($tail.Contains('=')) {
                $eqIndex = $tail.IndexOf('=')
                $owner = '--' + $tail.Substring(0, $eqIndex)
                $input = Find-MambaRigInput -PathKey $pathKey -Spelling $owner
                if ($null -ne $input -and -not $input.IsFlag) {
                    $usedNonRepeatable[$owner] = $true
                }
                continue
            }
            $input = Find-MambaRigInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('-', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 1) {
            $input = Find-MambaRigInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            continue
        }

        $positionalIndex = $positionalIndex + 1
    }

    return [PSCustomObject]@{
        ResolvedPath = $resolved
        PendingValueOwner = $pendingValueOwner
        AfterDoubleDash = $afterDoubleDash
        PositionalIndex = $positionalIndex
        UsedNonRepeatable = $usedNonRepeatable
        WordToComplete = $WordToComplete
    }
}

function Write-MambaRigCompletionResult {
    param(
        [Parameter(Mandatory)][string]$CompletionText,
        [Parameter(Mandatory)][string]$ListItemText,
        [Parameter(Mandatory)][string]$ResultType,
        [string]$Description
    )
    if ([string]::IsNullOrEmpty($Description)) { $Description = ' ' }
    [System.Management.Automation.CompletionResult]::new(
        $CompletionText,
        $ListItemText,
        $ResultType,
        $Description
    ) | Write-Output
}
Register-ArgumentCompleter -Native -CommandName 'rig' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    try {
        $state = Resolve-MambaRigState -WordToComplete $wordToComplete -CursorPosition $cursorPosition -CommandAst $commandAst
    } catch { return }
    try {
        $pathKey = ($state.ResolvedPath -join '.')
        if ($state.AfterDoubleDash) {
            $handler = $script:MambaRigVariadicHandlers[$pathKey]
            if ($null -eq $handler) { return }
            $emit = $handler.Repeatable -or ($state.PositionalIndex -lt 0)
            if (-not $emit) { return }
            foreach ($choice in $handler.Choices) {
                if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                    Write-MambaRigCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                }
            }
            return
        }
        if ($null -ne $state.PendingValueOwner) {
            $handler = $script:MambaRigValueHandlers["$pathKey.$($state.PendingValueOwner)"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaRigCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:MambaRigInputs[$pathKey]
        $currentWord = $state.WordToComplete
        $wantLong = $currentWord.StartsWith('--', [System.StringComparison]::Ordinal)
        $wantShort = (-not $wantLong) -and $currentWord.StartsWith('-', [System.StringComparison]::Ordinal)
        if ($null -ne $inputs) {
            foreach ($input in $inputs) {
                $spelling = $input.Spelling
                if ($wantLong -and -not $spelling.StartsWith('--', [System.StringComparison]::Ordinal)) { continue }
                if ($wantShort -and (-not $spelling.StartsWith('-', [System.StringComparison]::Ordinal) -or $spelling.StartsWith('--', [System.StringComparison]::Ordinal))) { continue }
                if (-not $spelling.StartsWith($currentWord, [System.StringComparison]::Ordinal)) { continue }
                if (-not $input.IsFlag -and -not $input.IsRepeatable -and -not $input.IsAccessor -and -not $input.IsHelp) {
                    if ($state.UsedNonRepeatable.ContainsKey($spelling)) { continue }
                }
                Write-MambaRigCompletionResult -CompletionText $spelling -ListItemText $spelling -ResultType 'ParameterName' -Description $input.Description
            }
        }
        if (-not $wantLong -and -not $wantShort) {
            $commands = $script:MambaRigChildren[$pathKey]
            if ($null -ne $commands) {
                foreach ($command in $commands) {
                    if ($command.Name.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaRigCompletionResult -CompletionText $command.Name -ListItemText $command.Name -ResultType 'Command' -Description $command.Description
                    }
                }
            }
            $positionals = $script:MambaRigPositionalSlots[$pathKey]
            if ($null -ne $positionals) {
                $entry = $positionals[($state.PositionalIndex + 1)]
                if ($null -ne $entry) {
                    foreach ($choice in $entry.Choices) {
                        if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                            Write-MambaRigCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description $entry.Description
                        }
                    }
                }
            }
        }
    } catch { }
}
