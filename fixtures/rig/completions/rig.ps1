<#
 PowerShell completion for rig.
 Generated; do not edit by hand.

 Completion fixture.

 To show a completion menu instead of cycling candidates:
 Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
#>
$script:MambaRigNativeCommands = @{
    'root' = 'root'
}

$script:MambaRigInputs = @{}
$script:MambaRigChildren = @{}
$script:MambaRigPositionalSlots = @{}
$script:MambaRigValueHandlers = @{}
$script:MambaRigVariadicHandlers = @{}

$script:MambaRigInputs['root'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--format'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaRigChildren['root'] = @(
    )
$script:MambaRigPositionalSlots['root'] = @{}
$script:MambaRigValueHandlers['root.--format'] = @('text', 'json')
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
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
        return
    }
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
        $currentWord = $state.WordToComplete
        if ($currentWord.StartsWith('--', [System.StringComparison]::Ordinal) -and $currentWord.Contains('=')) {
            $equalsIndex = $currentWord.IndexOf('=')
            $owner = $currentWord.Substring(0, $equalsIndex)
            $valuePrefix = $currentWord.Substring($equalsIndex + 1)
            $handler = $script:MambaRigValueHandlers["$pathKey.$owner"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($valuePrefix, [System.StringComparison]::Ordinal)) {
                        $completionText = "$owner=$choice"
                        Write-MambaRigCompletionResult -CompletionText $completionText -ListItemText $completionText -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:MambaRigInputs[$pathKey]
        $wantLong = $currentWord.StartsWith('--', [System.StringComparison]::Ordinal)
        $wantShort = (-not $wantLong) -and $currentWord.StartsWith('-', [System.StringComparison]::Ordinal)
        if (($wantLong -or $wantShort) -and $null -ne $inputs) {
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
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
    }
}
