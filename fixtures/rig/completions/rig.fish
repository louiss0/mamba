# Completion for rig: Completion fixture.
function __mamba_segment_field
    set -l fields (string split '|' -- $argv[1])
    string split ',' -- $fields[$argv[2]]
end

function __mamba_separate_width
    if test (count $argv) -lt 3
        echo 2
        return
    end
    set -l next $argv[3]
    if test "$next" = --
        echo 1
    else if not string match -q -- '-*' "$next"; or test "$next" = -
        echo 2
    else if contains -- $argv[2] (__mamba_segment_field $argv[1] 7); and string match -rq -- '^-[0-9]' "$next"
        echo 2
    else
        echo 1
    end
end

function __mamba_input_width
    set -l spec $argv[1]
    set -l token $argv[2]
    set -l next $argv[3]
    if string match -q -- '--*' $token
        set -l long (string replace -r '^--' '' -- $token)
        set -l parts (string split -m 1 '=' -- $long)
        if contains -- $parts[1] (__mamba_segment_field $spec 4)
            if test (count $parts) -eq 1
                __mamba_separate_width $spec --$parts[1] $next
            else
                echo 1
            end
            return
        end
        if contains -- $parts[1] (__mamba_segment_field $spec 2)
            echo 1
            return
        end
        echo 0
        return
    end
    if string match -q -- '-*' $token
        set -l short (string sub -s 2 -- $token)
        set -l parts (string split -m 1 '=' -- $short)
        if test (count $parts) -gt 1
            set -l letters (string split '' -- $parts[1])
            if not contains -- $letters[-1] (__mamba_segment_field $spec 5)
                echo 0
                return
            end
            set -e letters[-1]
            for letter in $letters
                if not contains -- $letter (__mamba_segment_field $spec 3)
                    echo 0
                    return
                end
            end
            echo 1
            return
        end
        if test (string length -- $short) -eq 1; and contains -- $short (__mamba_segment_field $spec 5)
            __mamba_separate_width $spec -$short $next
            return
        end
        for name in (string split '' -- $short)
            if not contains -- $name (__mamba_segment_field $spec 3)
                echo 0
                return
            end
        end
        if test -n "$short"
            echo 1
            return
        end
    end
    echo 0
end

function __mamba_path_state
    set -l mode $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l selecting true
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            set selecting false
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l next_offset (math $offset + 1)
        set -l width (__mamba_input_width $specs[$depth] $token $tokens[$next_offset])
        if test $width -gt 0
            if test $width -eq 2; and test $offset -eq (count $tokens)
                set selecting false
            end
            set offset (math $offset + $width)
            continue
        end
        set selecting false
        break
    end
    if test $depth -ne (count $specs)
        return 1
    end
    if test "$mode" = selecting
        test "$selecting" = true
        return
    end
    return 0
end

function __mamba_at_path
    __mamba_path_state path $argv
end

function __mamba_selecting_child
    __mamba_path_state selecting $argv
end

function __mamba_after_double_dash
    contains -- -- (commandline -xpc)
end

function __mamba_option_available
    set -l option --$argv[1]
    set -l short $argv[2]
    set -l repeatable $argv[3]
    if test "$repeatable" = true
        return 0
    end
    set -l tokens (commandline -xpc)
    for index in (seq (count $tokens))
        set -l token $tokens[$index]
        if string match -q -- "$option=*" $token
            return 1
        end
        if test "$token" = "$option"
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
        if test "$short" != _; and test "$token" = -$short
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
    end
    return 0
end

function __mamba_value_choices
    set -l current (commandline -ct)
    for candidate in $argv
        if string match -q -- '-*=*' "$current"; or not string match -q -- '-*' "$candidate"; or test "$candidate" = -
            printf '%s\n' "$candidate"
        end
    end
end

function __mamba_choice_unused
    set -l option --$argv[1]
    set -l short $argv[2]
    set -l choice $argv[3]
    set -l tokens (commandline -xpc)
    for index in (seq (count $tokens))
        set -l token $tokens[$index]
        if test "$token" = "$option=$choice"
            return 1
        end
        if test "$token" = "$option"; or begin; test "$short" != _; and test "$token" = -$short; end
            set -l next (math $index + 1)
            if test $next -le (count $tokens); and test "$tokens[$next]" = "$choice"
                return 1
            end
        end
        if test "$short" != _
            set -l head (string match -r -- "^-[A-Za-z0-9]*$short=" "$token")
            if test (count $head) -gt 0; and test "$token" = "$head$choice"
                return 1
            end
        end
    end
    return 0
end

function __mamba_unique_choices
    set -l option $argv[1]
    set -l short $argv[2]
    set -e argv[1..2]
    for choice in $argv
        if __mamba_choice_unused $option $short "$choice"
            __mamba_value_choices "$choice"
        end
    end
end

function __mamba_positional_slot
    set -l target $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l count 0
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l next_offset (math $offset + 1)
        set -l width (__mamba_input_width $specs[$depth] $token $tokens[$next_offset])
        if test $width -gt 0
            set offset (math $offset + $width)
            continue
        end
        if test $depth -lt (count $specs)
            return 1
        end
        set count (math $count + 1)
        set offset (math $offset + 1)
    end
    test $depth -eq (count $specs); and test $count -eq $target
end

function __mamba_variadic_available
    if test "$argv[1]" = true
        return 0
    end
    set -l after_separator false
    set -l count 0
    for token in (commandline -xpc)
        if test "$after_separator" = true
            set count (math $count + 1)
        else if test "$token" = --
            set after_separator true
        end
    end
    test $count -eq 0
end

complete -c rig -s h -l help -d 'Show this help message.'
complete -c rig -n '__mamba_selecting_child \'rig|help|h|||rig|\'' -f -a 'rig' -d 'Completion fixture.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\'' -s h -l help -d 'Show this help message.'
complete -c rig -n '__mamba_selecting_child \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\'' -f -a 'deploy ship' -d 'Deploy a build.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'' -s h -l help -d 'Show this help message.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'' -l dry-run -d 'Report without deploying.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'' -l no-dry-run -d 'Report without deploying.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'' -s r -l retries -d 'Retry a failed deploy.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available format _ false' -l format -x -a '(__mamba_value_choices text json yaml)' -d 'Output format.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available tag t true' -s t -l tag -r -d 'Tag to apply.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available replicas _ false' -l replicas -x -d 'Replica count.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available level _ false' -l level -x -a '(__mamba_value_choices debug info warn)' -d 'Log level.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available token k false' -s k -l token -r -d 'Deploy token.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available host _ false' -l host -r -d 'Deploy host.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available port _ false' -l port -r -d 'Deploy port.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available log _ false' -l log -r -d 'Write a log.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available report _ false' -l report -r -d 'Write a report.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available database.dsn _ false' -l database.dsn -r -d 'Connection string.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available database.pool.size _ false' -l database.pool.size -x -d 'Pool size.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'deploy,ship|help,quiet,dry-run,no-dry-run,retries|h,q,r|format,tag,replicas,level,token,host,port,log,report,database.dsn,database.pool.size,database.pool.mode|t,k||--replicas,--database.pool.size\'; and __mamba_option_available database.pool.mode _ false' -l database.pool.mode -x -a '(__mamba_value_choices text json yaml)'
complete -c rig -n '__mamba_selecting_child \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\'' -f -a 'status' -d 'Report status.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'status|help,quiet,watch|h,q,w||||\'' -s h -l help -d 'Show this help message.'
complete -c rig -n '__mamba_at_path \'rig|help|h|||rig|\' \'rig|help,quiet|h,q|||deploy,ship,status|\' \'status|help,quiet,watch|h,q,w||||\'' -s w -l watch -d 'Keep watching.'
