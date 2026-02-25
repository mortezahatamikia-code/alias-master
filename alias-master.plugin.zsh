if [[ -n "$ALIAS_MASTER_LOADED" ]]; then return; fi
export ALIAS_MASTER_LOADED=1
export ALIAS_MASTER_VERSION='4.1.0'

0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
ALIAS_MASTER_DIR="${0:h}"

if ! type "tput" > /dev/null 2>&1; then
    NONE=$'\e[0m'
    BOLD=$'\e[1m'
    RED=$'\e[31m'
    YELLOW=$'\e[33m'
    PURPLE=$'\e[35m'
    GREEN=$'\e[32m'
else
    NONE="$(tput sgr0)"
    BOLD="$(tput bold)"
    RED="$(tput setaf 1)"
    YELLOW="$(tput setaf 3)"
    PURPLE="$(tput setaf 5)"
    GREEN="$(tput setaf 2)"
fi

ICON_WARN=" "
if [[ "$LANG" == *UTF-8* || "$LC_ALL" == *UTF-8* || "$LC_CTYPE" == *UTF-8* ]]; then
    ICON_WARN=" 💡 "
fi

typeset -g _AM_GIT_CACHE_FILE="${TMPDIR:-/tmp}/alias_master_git_cache_${UID}.zsh"
typeset -g _AM_PREFS_FILE="${HOME}/.alias_master_prefs"
typeset -g _AM_GLOBAL_DISABLE=0
typeset -gA _AM_DISABLED_LOCALS
typeset -gA _AM_GIT_ALIASES
typeset -gA _AM_FORWARD_ALIASES
typeset -gA _AM_REVERSE_ALIASES
typeset -g _AM_CURRENT_TRIGGER=""

function _am_load_prefs() {
    _AM_GLOBAL_DISABLE=0
    _AM_DISABLED_LOCALS=()
    if [[ -f "$_AM_PREFS_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" == "GLOBAL_DISABLE=1" ]]; then
                _AM_GLOBAL_DISABLE=1
            elif [[ "$line" == LOCAL_DISABLE:* ]]; then
                local key="${line#LOCAL_DISABLE:}"
                _AM_DISABLED_LOCALS[$key]=1
            fi
        done < "$_AM_PREFS_FILE"
    fi
}

function _am_save_prefs() {
    local tmp_file="${_AM_PREFS_FILE}.tmp.$$"
    if (( _AM_GLOBAL_DISABLE )); then
        echo "GLOBAL_DISABLE=1" > "$tmp_file"
    else
        echo "GLOBAL_DISABLE=0" > "$tmp_file"
    fi
    for k in "${(@k)_AM_DISABLED_LOCALS}"; do
        echo "LOCAL_DISABLE:$k" >> "$tmp_file"
    done
    mv -f "$tmp_file" "$_AM_PREFS_FILE" 2>/dev/null
}

_am_load_prefs

function _am_async_git_cache() {
    local do_update=0
    if [[ ! -f "$_AM_GIT_CACHE_FILE" ]]; then
        do_update=1
    else
        local cache_time
        read -r cache_time < "$_AM_GIT_CACHE_FILE" 2>/dev/null
        cache_time="${cache_time#\#}"
        local now=$(date +%s 2>/dev/null || echo 0)
        if (( now - cache_time > 60 )); then
            do_update=1
        fi
    fi

    if (( do_update )); then
        local pre_now=$(date +%s 2>/dev/null || echo 0)
        if [[ ! -f "$_AM_GIT_CACHE_FILE" ]]; then
            echo "#$pre_now" > "$_AM_GIT_CACHE_FILE"
        fi
        
        (
            local tmp_file="${_AM_GIT_CACHE_FILE}.tmp.$$"
            echo "#$pre_now" > "$tmp_file"
            echo "typeset -gA _AM_GIT_ALIASES" >> "$tmp_file"
            echo "_AM_GIT_ALIASES=()" >> "$tmp_file"
            if command -v git >/dev/null 2>&1; then
                git config --get-regexp "^alias\." 2>/dev/null | while read -r line; do
                    local gk="${line%% *}"
                    gk="${gk#alias.}"
                    local gv="${line#* }"
                    gv="${gv//\'/\'\\\'\'}"
                    echo "_AM_GIT_ALIASES['$gk']='$gv'" >> "$tmp_file"
                done
            fi
            mv -f "$tmp_file" "$_AM_GIT_CACHE_FILE" 2>/dev/null
        ) &!
    fi

    if [[ -f "$_AM_GIT_CACHE_FILE" ]]; then
        source "$_AM_GIT_CACHE_FILE" 2>/dev/null
    fi
}

function _am_build_dicts() {
    _AM_FORWARD_ALIASES=()
    _AM_REVERSE_ALIASES=()

    for k in "${(@k)aliases}"; do
        if [[ ${ALIAS_MASTER_IGNORED_ALIASES[(r)$k]} == "$k" ]]; then continue; fi
        local v="${aliases[$k]#nocorrect }"
        _AM_FORWARD_ALIASES[$k]="$v"
        if [[ -z "${_AM_REVERSE_ALIASES[$v]}" || ${#k} -lt ${#${_AM_REVERSE_ALIASES[$v]}} ]]; then
            _AM_REVERSE_ALIASES[$v]="$k"
        fi
    done

    for gk in "${(@k)_AM_GIT_ALIASES}"; do
        local gv="${_AM_GIT_ALIASES[$gk]}"
        local full_k="git $gk"
        local full_v="git $gv"
        _AM_FORWARD_ALIASES[$full_k]="$full_v"
        if [[ -z "${_AM_REVERSE_ALIASES[$full_v]}" || ${#full_k} -lt ${#${_AM_REVERSE_ALIASES[$full_v]}} ]]; then
            _AM_REVERSE_ALIASES[$full_v]="$full_k"
        fi
    done
}

function _write_alias_master_buffer() {
    _ALIAS_MASTER_BUFFER+="$@"
    local position="${ALIAS_MASTER_MESSAGE_POSITION:-before}"
    if [[ "$position" = "before" ]]; then
        _flush_alias_master_buffer
    elif [[ "$position" != "after" ]]; then
        (>&2 printf "${RED}${BOLD}Unknown value for ALIAS_MASTER_MESSAGE_POSITION '$position'. Expected value 'before' or 'after'${NONE}\n")
        _flush_alias_master_buffer
    fi
}

function _flush_alias_master_buffer() {
    (>&2 printf "$_ALIAS_MASTER_BUFFER")
    _ALIAS_MASTER_BUFFER=""
}

function alias_master_message() {
    local DEFAULT_MESSAGE_FORMAT="${BOLD}${YELLOW}${ICON_WARN}existing %alias_type for ${PURPLE}\"%command\"${YELLOW}: ${GREEN}\"%alias\"${NONE}"
    local alias_type_arg="${1}"
    local command_arg="${2}"
    local alias_arg="${3}"

    command_arg="${command_arg//\%/%%}"
    command_arg="${command_arg//\\/\\\\}"

    local MESSAGE="${ALIAS_MASTER_MESSAGE_FORMAT:-"$DEFAULT_MESSAGE_FORMAT"}"
    MESSAGE="${MESSAGE//\%alias_type/$alias_type_arg}"
    MESSAGE="${MESSAGE//\%command/$command_arg}"
    MESSAGE="${MESSAGE//\%alias/$alias_arg}"

    _write_alias_master_buffer "$MESSAGE\n"
}

function _check_alias_master_hardcore() {
    local alias_name="$1"
    local hardcore_lookup="${ALIAS_MASTER_HARDCORE_ALIASES[(r)$alias_name]}"
    if (( ${+ALIAS_MASTER_HARDCORE} )) || [[ -n "$hardcore_lookup" && "$hardcore_lookup" == "$alias_name" ]]; then
        _write_alias_master_buffer "${BOLD}${RED}Alias Master hardcore mode enabled. Use your aliases!${NONE}\n"
        kill -s INT $$
    fi
}

function _am_check_execution() {
    if (( _AM_GLOBAL_DISABLE )); then return; fi
    local typed="$1"
    if [[ "$typed" = "sudo "* ]]; then return; fi

    for key in "${(@k)galiases}"; do
         if [[ ${ALIAS_MASTER_IGNORED_GLOBAL_ALIASES[(r)$key]} == "$key" ]]; then continue; fi
         if [[ -n "${_AM_DISABLED_LOCALS[$key]}" ]]; then continue; fi
         local value="${galiases[$key]}"
         if [[ "$typed" == *"$value"* && "$typed" != *"$key"* ]]; then
             alias_master_message "global alias" "$value" "$key"
             _check_alias_master_hardcore "$key"
         fi
    done

    local best_match=""
    local best_match_len=0
    
    for v in "${(@k)_AM_REVERSE_ALIASES}"; do
        if [[ "$typed" == "$v" || "$typed" == "$v "* ]]; then
            if [[ ${#v} -gt $best_match_len ]]; then
                best_match="${_AM_REVERSE_ALIASES[$v]}"
                best_match_len=${#v}
            fi
        fi
    done

    if [[ -n "$best_match" && "$typed" != "$best_match" && "$typed" != "$best_match "* ]]; then
         if [[ -z "${_AM_DISABLED_LOCALS[$best_match]}" ]]; then
             local val="${_AM_FORWARD_ALIASES[$best_match]}"
             local a_type="alias"
             [[ "$best_match" == "git "* ]] && a_type="git alias"
             
             alias_master_message "$a_type" "$val" "$best_match"
             _check_alias_master_hardcore "$best_match"
         fi
    fi
}

function _alias_master_precmd() {
    _flush_alias_master_buffer
    _am_async_git_cache
    _am_build_dicts
}

function disable_alias_master() {
    add-zsh-hook -D preexec _am_check_execution
    add-zsh-hook -D precmd _alias_master_precmd
}

function enable_alias_master() {
    disable_alias_master
    add-zsh-hook preexec _am_check_execution
    add-zsh-hook precmd _alias_master_precmd
}

autoload -Uz add-zsh-hook
enable_alias_master

autoload -Uz add-zle-hook-widget
typeset -g _AM_LAST_HINT=""
typeset -g _AM_LAST_HL_START=""
typeset -g _AM_LAST_HL_END=""

_alias_master_zle_redraw() {
    local expected_hint=""
    _AM_CURRENT_TRIGGER=""

    if [[ -n "$BUFFER" ]]; then
        local stripped="$BUFFER"
        while [[ "$stripped" =~ "^(sudo|env|noglob|command|builtin|time) +(.*)" ]]; do
            stripped="${match[2]}"
        done
        
        if [[ -n "$stripped" ]]; then
            local first_word="${stripped%% *}"
            local best_len=0
            local reverse_key=""
            
            for v in "${(@k)_AM_REVERSE_ALIASES}"; do
                if [[ "$stripped" == "$v" || "$stripped" == "$v "* ]]; then
                    if [[ ${#v} -gt $best_len ]]; then
                        best_len=${#v}
                        reverse_key="${_AM_REVERSE_ALIASES[$v]}"
                    fi
                fi
            done
            
            if [[ -n "$reverse_key" ]]; then
                _AM_CURRENT_TRIGGER="$reverse_key"
                if (( _AM_GLOBAL_DISABLE == 0 )) && [[ -z "${_AM_DISABLED_LOCALS[$reverse_key]}" ]]; then
                    expected_hint="${ICON_WARN}alias: $reverse_key"
                fi
            else
                local fw_trigger=""
                if [[ -n "${_AM_FORWARD_ALIASES[$first_word]}" ]]; then
                    fw_trigger="$first_word"
                elif [[ "$first_word" == "git" ]]; then
                    local git_subcmd="${stripped#git }"
                    git_subcmd="${git_subcmd%% *}"
                    local full_git="git $git_subcmd"
                    if [[ -n "${_AM_FORWARD_ALIASES[$full_git]}" ]]; then
                        fw_trigger="$full_git"
                    fi
                fi
                
                if [[ -n "$fw_trigger" ]]; then
                    _AM_CURRENT_TRIGGER="$fw_trigger"
                    if (( _AM_GLOBAL_DISABLE == 0 )) && [[ -z "${_AM_DISABLED_LOCALS[$fw_trigger]}" ]]; then
                        local expansion="${_AM_FORWARD_ALIASES[$fw_trigger]}"
                        if [[ "$stripped" != "$expansion"* && "$fw_trigger" != "$expansion" ]]; then
                            expected_hint=" => $expansion"
                        fi
                    fi
                fi
            fi
        fi
    fi

    if [[ -n "$_AM_LAST_HINT" ]]; then
        POSTDISPLAY="${POSTDISPLAY%"$_AM_LAST_HINT"}"
    fi

    if [[ -n "$_AM_LAST_HL_START" && -n "$_AM_LAST_HL_END" ]]; then
        region_highlight=("${(@)region_highlight:#$_AM_LAST_HL_START $_AM_LAST_HL_END *}")
    fi

    local formatted_hint=""
    if [[ -n "$expected_hint" ]]; then
        formatted_hint=$'\n'"$expected_hint"
        POSTDISPLAY+="$formatted_hint"
        
        _AM_LAST_HL_START=$(( ${#BUFFER} + ${#POSTDISPLAY} - ${#formatted_hint} ))
        _AM_LAST_HL_END=$(( _AM_LAST_HL_START + ${#formatted_hint} ))
        region_highlight+=("$_AM_LAST_HL_START $_AM_LAST_HL_END fg=242")
    else
        _AM_LAST_HL_START=""
        _AM_LAST_HL_END=""
    fi
    _AM_LAST_HINT="$formatted_hint"
}

_alias_master_zle_finish() {
    if [[ -n "$_AM_LAST_HINT" ]]; then
        POSTDISPLAY="${POSTDISPLAY%"$_AM_LAST_HINT"}"
        _AM_LAST_HINT=""
    fi
    if [[ -n "$_AM_LAST_HL_START" && -n "$_AM_LAST_HL_END" ]]; then
        region_highlight=("${(@)region_highlight:#$_AM_LAST_HL_START $_AM_LAST_HL_END *}")
        _AM_LAST_HL_START=""
        _AM_LAST_HL_END=""
    fi
    zle -R
}

_am_toggle_local_hint() {
    if [[ -n "$_AM_CURRENT_TRIGGER" ]]; then
        if [[ -n "${_AM_DISABLED_LOCALS[$_AM_CURRENT_TRIGGER]}" ]]; then
            unset "_AM_DISABLED_LOCALS[$_AM_CURRENT_TRIGGER]"
        else
            _AM_DISABLED_LOCALS[$_AM_CURRENT_TRIGGER]=1
        fi
        _am_save_prefs
        _alias_master_zle_redraw
        zle -R
    fi
}

_am_toggle_global_hint() {
    if (( _AM_GLOBAL_DISABLE )); then
        _AM_GLOBAL_DISABLE=0
    else
        _AM_GLOBAL_DISABLE=1
    fi
    _am_save_prefs
    _alias_master_zle_redraw
    zle -R
}

zle -N _alias_master_zle_redraw
add-zle-hook-widget line-pre-redraw _alias_master_zle_redraw

zle -N _alias_master_zle_finish
add-zle-hook-widget zle-line-finish _alias_master_zle_finish

zle -N _am_toggle_local_hint
zle -N _am_toggle_global_hint

bindkey '\eh' _am_toggle_local_hint
bindkey '\eah' _am_toggle_global_hint

function check_alias_usage() {
    local limit="${1:-${HISTSIZE:-9000000000000000}}"
    local key
    declare -A usage
    for key in "${(@k)aliases}"; do usage[$key]=0; done

    local -a histfile_lines
    histfile_lines=("${(@f)$(<$HISTFILE)}")
    histfile_lines=("${histfile_lines[@]#*;}")

    local current=0
    local total=${#histfile_lines}
    if [[ $total -gt $limit ]]; then total=$limit; fi

    local entry
    for line in ${histfile_lines[@]} ; do
        for entry in ${(@s/|/)line}; do
            entry=${entry##*[[:space:]]}
            local word=${entry[(w)1]}
            if [[ -n ${usage[$word]} ]]; then (( usage[$word]++ )); fi
        done
        (( current++ ))
        printf "Analysing:[$current/$total]\r"
    done
    printf "\r\033[K"

    for key in ${(k)usage}; do
        echo "${usage[$key]}: ${(q+)key}=${(q+)aliases[$key]}"
    done | sort -rn -k1
}

function als() {
    (( $+commands[python3] )) || {
        echo "[error] No python executable detected"
        return
    }
    alias | python3 "$ALIAS_MASTER_DIR/cheatsheet.py" "$@"
}