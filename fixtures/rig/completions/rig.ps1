<#
 PowerShell completion for rig.
 Generated; do not edit by hand.

 Completion fixture.

 To show a completion menu instead of cycling candidates:
 Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
#>
$script:Mamba007200690067Inputs = New-Object "System.Collections.Generic.Dictionary[string,object]" ([System.StringComparer]::Ordinal)
$script:Mamba007200690067Children = New-Object "System.Collections.Generic.Dictionary[string,object]" ([System.StringComparer]::Ordinal)
$script:Mamba007200690067PositionalSlots = New-Object "System.Collections.Generic.Dictionary[string,object]" ([System.StringComparer]::Ordinal)
$script:Mamba007200690067ValueHandlers = New-Object "System.Collections.Generic.Dictionary[string,object]" ([System.StringComparer]::Ordinal)
$script:Mamba007200690067VariadicHandlers = New-Object "System.Collections.Generic.Dictionary[string,object]" ([System.StringComparer]::Ordinal)

$script:Mamba007200690067Inputs['root'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    )
$script:Mamba007200690067Children['root'] = @(
    [PSCustomObject]@{ Name = 'rig'; Canonical = 'rig'; Description = 'Completion fixture.' }
    )
$script:Mamba007200690067PositionalSlots['root'] = @{}
$script:Mamba007200690067Inputs['root.rig'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    )
$script:Mamba007200690067Children['root.rig'] = @(
    [PSCustomObject]@{ Name = 'deploy'; Canonical = 'deploy'; Description = 'Deploy a build.' }
    [PSCustomObject]@{ Name = 'ship'; Canonical = 'deploy'; Description = 'Alias for deploy. Deploy a build.' }
    [PSCustomObject]@{ Name = 'status'; Canonical = 'status'; Description = 'Report status.' }
    )
$script:Mamba007200690067PositionalSlots['root.rig'] = @{}
$script:Mamba007200690067Inputs['root.rig.deploy'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--dry-run'; Description = 'Report without deploying.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--no-dry-run'; Description = 'Report without deploying.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--retries'; Description = 'Retry a failed deploy.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-r'; Description = 'Retry a failed deploy.'; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = 'Output format.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--tag'; Description = 'Tag to apply.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-t'; Description = 'Tag to apply.'; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--replicas'; Description = 'Replica count.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--level'; Description = 'Log level.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--token'; Description = 'Deploy token.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-k'; Description = 'Deploy token.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--host'; Description = 'Deploy host.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--port'; Description = 'Deploy port.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--log'; Description = 'Write a log.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--report'; Description = 'Write a report.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--database.dsn'; Description = 'Connection string.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--database.pool.size'; Description = 'Pool size.'; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsNumeric = $true; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--database.pool.mode'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $true; IsNumeric = $false; IsHelp = $false }
    )
$script:Mamba007200690067Children['root.rig.deploy'] = @(
    )
$script:Mamba007200690067PositionalSlots['root.rig.deploy'] = @{
    }
$script:Mamba007200690067ValueHandlers['root.rig.deploy.--format'] = @('text', 'json', 'yaml')
$script:Mamba007200690067ValueHandlers['root.rig.deploy.--replicas'] = @('1', '2', '3', '4')
$script:Mamba007200690067ValueHandlers['root.rig.deploy.--level'] = @('debug', 'info', 'warn')
$script:Mamba007200690067ValueHandlers['root.rig.deploy.--database.pool.mode'] = @('text', 'json', 'yaml')
$script:Mamba007200690067VariadicHandlers['root.rig.deploy'] = [PSCustomObject]@{ Choices = @(); }
$script:Mamba007200690067Inputs['root.rig.status'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--watch'; Description = 'Keep watching.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-w'; Description = 'Keep watching.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsNumeric = $false; IsHelp = $false }
    )
$script:Mamba007200690067Children['root.rig.status'] = @(
    )
$script:Mamba007200690067PositionalSlots['root.rig.status'] = @{
    }
function Update-Mamba007200690067StateObject {
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

function Find-Mamba007200690067Input {
    param(
        [Parameter(Mandatory)][string]$PathKey,
        [Parameter(Mandatory)][string]$Spelling
    )
    $inputs = $script:Mamba007200690067Inputs[$PathKey]
    if ($null -eq $inputs) { return $null }
    foreach ($input in $inputs) {
        if ($input.Spelling -ceq $Spelling) { return $input }
    }
    return $null
}

function Resolve-Mamba007200690067State {
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
        if (-not (Update-Mamba007200690067StateObject -CursorPosition $CursorPosition -Element $el)) { continue }
        $isLastElement = ($i -eq $elements.Count - 1)
        $tokenText = if ($el -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $el.Value } else { $el.Extent.Text }
        # The last AST element is the completion word only while the cursor
        # is inside it or immediately after it; a trailing space means the
        # last element has already been supplied.
        $isWord = $isLastElement -and ($el.Extent.EndOffset -ge $CursorPosition)

        if ($isWord) { continue }

        # Syntax owns separate values independently of their content validators.
        if ($null -ne $pendingValueOwner) {
            $pendingInput = Find-Mamba007200690067Input -PathKey ($resolved -join '.') -Spelling $pendingValueOwner
            $ownsValue = $tokenText -ne '--' -and (
                -not $tokenText.StartsWith('-') -or $tokenText -eq '-' -or
                ($pendingInput.IsNumeric -and $tokenText -match '^-[0-9]')
            )
            if ($ownsValue) {
                $usedNonRepeatable[$pendingValueOwner] = $true
                $pendingValueOwner = $null
                continue
            }
            $pendingValueOwner = $null
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
        $children = @($script:Mamba007200690067Children[$pathKey])
        $canonical = $null
        foreach ($child in $children) {
            if ($child.Name -ceq $tokenText) {
                $canonical = $child.Canonical
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
                $input = Find-Mamba007200690067Input -PathKey $pathKey -Spelling $owner
                if ($null -ne $input -and -not $input.IsFlag) {
                    $usedNonRepeatable[$owner] = $true
                }
                continue
            }
            $input = Find-Mamba007200690067Input -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('-', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 1) {
            $input = Find-Mamba007200690067Input -PathKey $pathKey -Spelling $tokenText
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

function Write-Mamba007200690067CompletionResult {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$CompletionText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ListItemText,
        [Parameter(Mandatory)][string]$ResultType,
        [string]$Description
    )
    if ([string]::IsNullOrEmpty($Description)) { $Description = ' ' }
    if ($ResultType -ceq 'ParameterValue' -and $CompletionText -cnotmatch '^[A-Za-z0-9_./=+-]+$') {
        $CompletionText = "'" + $CompletionText.Replace("'", "''") + "'"
    }
    if ([string]::IsNullOrEmpty($ListItemText)) { $ListItemText = $CompletionText }
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
        $state = Resolve-Mamba007200690067State -WordToComplete $wordToComplete -CursorPosition $cursorPosition -CommandAst $commandAst
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
        return
    }
    try {
        $pathKey = ($state.ResolvedPath -join '.')
        if ($state.AfterDoubleDash) {
            $handler = $script:Mamba007200690067VariadicHandlers[$pathKey]
            if ($null -eq $handler) { return }
            $emit = $handler.Repeatable -or ($state.PositionalIndex -lt 0)
            if (-not $emit) { return }
            foreach ($choice in $handler.Choices) {
                if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                    Write-Mamba007200690067CompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                }
            }
            return
        }
        if ($null -ne $state.PendingValueOwner) {
            $handler = $script:Mamba007200690067ValueHandlers["$pathKey.$($state.PendingValueOwner)"]
            if ($null -ne $handler) {
                $owner = Find-Mamba007200690067Input -PathKey $pathKey -Spelling $state.PendingValueOwner
                foreach ($choice in $handler) {
                    if (-not $owner.IsNumeric -and $choice.StartsWith('-') -and $choice -cne '-') { continue }
                    if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-Mamba007200690067CompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $currentWord = $state.WordToComplete
        if ($currentWord.StartsWith('-', [System.StringComparison]::Ordinal) -and $currentWord.Contains('=')) {
            $equalsIndex = $currentWord.IndexOf('=')
            $prefix = $currentWord.Substring(0, $equalsIndex)
            $owner = $prefix
            if (-not $prefix.StartsWith('--', [System.StringComparison]::Ordinal)) {
                if ($prefix.Length -lt 2) { return }
                for ($i = 1; $i -lt $prefix.Length - 1; $i++) {
                    $flag = Find-Mamba007200690067Input -PathKey $pathKey -Spelling ('-' + $prefix[$i])
                    if ($null -eq $flag -or -not $flag.IsFlag) { return }
                }
                $owner = '-' + $prefix[$prefix.Length - 1]
            }
            $valuePrefix = $currentWord.Substring($equalsIndex + 1)
            $handler = $script:Mamba007200690067ValueHandlers["$pathKey.$owner"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($valuePrefix, [System.StringComparison]::Ordinal)) {
                        $completionText = "$prefix=$choice"
                        Write-Mamba007200690067CompletionResult -CompletionText $completionText -ListItemText $completionText -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:Mamba007200690067Inputs[$pathKey]
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
                Write-Mamba007200690067CompletionResult -CompletionText $spelling -ListItemText $spelling -ResultType 'ParameterName' -Description $input.Description
            }
        }
        if (-not $wantLong -and -not $wantShort) {
            $commands = $script:Mamba007200690067Children[$pathKey]
            if ($null -ne $commands) {
                foreach ($command in $commands) {
                    if ($command.Name.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-Mamba007200690067CompletionResult -CompletionText $command.Name -ListItemText $command.Name -ResultType 'Command' -Description $command.Description
                    }
                }
            }
            $positionals = $script:Mamba007200690067PositionalSlots[$pathKey]
            if ($null -ne $positionals) {
                $entry = $positionals[($state.PositionalIndex + 1)]
                if ($null -ne $entry) {
                    foreach ($choice in $entry.Choices) {
                        if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                            Write-Mamba007200690067CompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description $entry.Description
                        }
                    }
                }
            }
        }
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
    }
}
