#!/usr/bin/env zsh

#Aliases and functions for tmux
alias tmux="tmux -f \"$TMUX_CONF_FILE\""
alias ts='tn sesh'

config_file="${TMUX_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}}/.tmux.sessionizer.json"
config=""
if [[ -f "$config_file" ]]; then
    config=$(<"$config_file")
else
    config='{"defaults": {"windows": 3, "commands": {}, "search_dirs" : ["~/Documents", "~/Desktop" ,"~/"] } }'
fi

function sanity_check() {
    if ! command -v tmux &>/dev/null; then
        echo "tmux is not installed. Please install it first."
        exit 1
    fi

    if ! command -v fzf &>/dev/null; then
        echo "fzf is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        echo "jq is not installed. Please install it first."
        exit 1
    fi
}

function ta() {
    sanity_check
    if [ "$#" -eq 1 ]; then
        tmux attach-session -t "$1"
    elif [ "$#" -eq 0 ]; then
        tmux attach-session
    fi
}

function tn() {
    sanity_check
    local session="$1"
    local win_override=""
    local template=""
    declare -a cmd_override=()

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -n | --num-windows)
            win_override="$2"
            shift 2
            ;;
        -c | --command)
            cmd_override+=("$2")
            shift 2
            ;;
        -t | --template)
            template="$2"
            shift 2
            ;;
        *)
            shift
            ;;
        esac
    done

    if [ -z "$session" ]; then
        echo "No session name provided."
        return 1
    fi

    local local_config_file
    local_config_file="$(pwd)/.tmux.sessionizer.json"
    if [[ -f "$local_config_file" ]]; then
        config=$(<"$local_config_file")
    fi



    # Determine template source
    local config_key="${template:-defaults}"

    # Determine number of windows
    local num_windows="$win_override"
    if [ -z "$num_windows" ] || ! [[ "$num_windows" =~ ^[0-9]+$ ]]; then
        num_windows=$(jq -r --arg key "$config_key" '
            if .[$key].windows then .[$key].windows
            else .defaults.windows end // 3
        ' <<<"$config")
    fi

    # Get commands
    declare -A commands_map

    if [ ${#cmd_override[@]} -gt 0 ]; then
        for i in {1..${#cmd_override[@]}}; do
            commands_map["$i"]="${cmd_override[$i]}"
        done
    else
        while IFS=$'\t' read -r win_num cmd; do
            # Append to array in case multiple commands per window
            commands_map["$win_num"]+="$cmd;"
        done < <(jq -r --arg key "$config_key" '
            if .[$key].commands then
                .[$key].commands
            else
                .defaults.commands
            end
            | to_entries[]
            | .key as $win
            | .value[]
            | "\($win)\t\(.)"
        ' <<<"$config")
    fi



    # Create session if not exists
    if ! tmux has-session -t "$session" 2>/dev/null; then
        tmux new-session -d -s "$session"
        for i in $(seq 1 $((num_windows - 1))); do
            tmux new-window -t "$session"
        done

        # Now send commands to specific windows
        for win_num_string in ${(on)${(k)commands_map}}; do
            local win_num=$((win_num_string + 0))
            local -a commands=()
            commands=("${(s/;/)commands_map[$win_num_string]}")  # split on ';' but keep spaces
            for ((i = 1; i <= ${#commands[@]}; i++)); do
                local cmd=${commands[$i]}
                [[ -n "$cmd" ]] && tmux send-keys -t "$session:$win_num" "$cmd" C-m
            done
        done

    fi

    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$session:1"
    else
        tmux attach-session -t "$session:1"
    fi
}

function tmux_list_templates(){
    local local_config_file="$(pwd)/.tmux.sessionizer.json"
    if [[ -f "$local_config_file" ]]; then
        config=$(<"$local_config_file")
    fi
    tmpfile=$(mktemp)
    printf '%s\n' "$config" > "$tmpfile"
    jq -r 'keys[]' "$tmpfile" | \
        fzf --height=50 --border --reverse --ansi \
        --preview "jq .{} $tmpfile"
    trap 'rm -f "$tmpfile"' EXIT
}

function tl() {
    sanity_check
    local _session_name=$(tmux ls | fzf --height=10 --border --reverse --ansi | sed 's/:.*//')
    if [ ! -z "$_session_name" ]; then
        tn "$_session_name" "$@"
    else
        echo "why you do this? huh ??"
    fi

}

function tk() {
    sanity_check
    local _session_name=$(tmux ls | fzf --height=10 --border --reverse --ansi | sed 's/:.*//')
    if [ ! -z "$_session_name" ]; then
        tmux kill-session -t "$_session_name"
    else
        echo "why you do this? huh ??"
    fi

}

function t() {
    local use_pwd_flag=0
    local template=""
    local all_args=("$@")
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -t|--template)
            template="$2"
            shift 2
            ;;
        --pwd)
            use_pwd_flag=1
            shift
            ;;
        *)
            shift
            ;;
        esac
    done

    local config_key="${template:-defaults}"
    local out_dir
    
    if [[ $use_pwd_flag -eq 0 ]];then
        local search_dirs=($(jq -r --arg key "$config_key" '
          if .[$key].search_dirs then .[$key].search_dirs[]
          else .defaults.search_dirs[] end
        ' <<<"$config"))

        # Fallback if empty
        if [[ ${#search_dirs[@]} -eq 0 ]]; then
            echo "Add search_dirs to the config"
            search_dirs=(~/Documents ~/Desktop ~/)
        fi


        # Expand ~ manually
        for ((i = 1; i <= ${#search_dirs[@]}; i++)); do
            search_dirs[$i]="${search_dirs[$i]/\~/$HOME}"
        done


        # Build fd arguments
        local fd_args=()
        for dir in "${search_dirs[@]}"; do
            fd_args+=("$dir")
        done

        out_dir="$(fd . "${fd_args[@]}" --type=d --hidden --exclude .git --max-depth 3 \
            | sort -u \
            | fzf --preview 'eza --tree --level=4 --color=always {} | head -200')"
    else
        out_dir=$(pwd)
    fi

    if [ ! -z "$out_dir" ]; then
        local curr_dir=$(pwd)
        cd $out_dir
        local tmux_session_name=$(basename $out_dir)
        tmux_session_name="${tmux_session_name//./_}"
        tn $tmux_session_name "${all_args[@]}"
        cd "$curr_dir"
    else
        echo "you fucked up"
    fi
}


function thelp() {
    local CYAN='%F{cyan}'
    local GREEN='%F{green}'
    local YELLOW='%F{yellow}'
    local RED='%F{red}'
    local RESET='%f'
    local BOLD='%B'
    local NORMAL='%b'

    print -P ""
    print -P "${GREEN}📦 TMUX Sessionizer Help${RESET}"
    print -P "-------------------------------"
    print -P "${CYAN}Available Commands:${RESET}"

    print -P ""
    print -P "${YELLOW}1) ta [session_name]${RESET}         - ${CYAN}Attach to a tmux session${RESET}"
    print -P "  ${GREEN}Usage:${RESET} ta"
    print -P "         ta my-session"

    print -P ""
    print -P "${YELLOW}2) tn [options] <session_name>${RESET} - ${CYAN}Create (if needed) and attach to a tmux session${RESET}"
    print -P "  ${GREEN}Options:${RESET}"
    print -P "    ${CYAN}-n, --num-windows <number>${RESET}    Set number of windows (overrides config)"
    print -P "    ${CYAN}-c, --command <cmd>${RESET}           Add a command to run in window (can be used multiple times)"
    print -P "    ${CYAN}-t, --template <template>${RESET}     Use a specific template from the config file"
    print -P "  ${GREEN}Example:${RESET}"
    print -P "    tn my-project"
    print -P "    tn -n 4 -c 'nvim .' -c 'git status' my-project"
    print -P "    tn -t rust my-rust-app"

    print -P ""
    print -P "${YELLOW}3) tl${RESET}                    - ${CYAN}List tmux sessions using fzf and attach${RESET}"
    print -P "  ${GREEN}Usage:${RESET} tl"

    print -P ""
    print -P "${YELLOW}4) tk${RESET}                    - ${CYAN}List tmux sessions using fzf and kill selected one${RESET}"
    print -P "  ${GREEN}Usage:${RESET} tk"

    print -P ""
    print -P "${YELLOW}5) t [options]${RESET}           - ${CYAN}Search directories (fzf + fd) and create a session${RESET}"
    print -P "  ${GREEN}Options:${RESET}"
    print -P "    ${CYAN}-t, --template <template>${RESET}     Use a specific template from config"
    print -P "  ${GREEN}Example:${RESET}"
    print -P "    t"
    print -P "    t -t python"
    print -P ""
    print -P "  This will:"
    print -P "    • Search for a folder"
    print -P "    • cd into it"
    print -P "    • Create a session named after the folder"
    print -P "    • Open with configured windows and commands"

    print -P ""
    print -P "${GREEN}⚙️ Config File System:${RESET}"
    print -P "  ${CYAN}Global config:${RESET} {XDG_CONFIG_HOME OR HOME/.config}/tmux/.tmux.sessionizer.json"
    print -P "  ${CYAN}Local (per-project):${RESET} {pwd}/.tmux.sessionizer.json (takes priority if present)"

    print -P "${GREEN}📄 Example Config File:${RESET}"
    print -P "${CYAN}{"
    print -P "  \"defaults\": {"
    print -P "    \"windows\": 3,"
    print -P "    \"commands\": {"
    print -P "      \"1\": [\"nvim .\"],"
    print -P "      \"2\": [\"htop\"],"
    print -P "      \"3\": [\"git status\"]"
    print -P "    },"
    print -P "    \"search_dirs\": [\"~/Documents\", \"~/Desktop\"]"
    print -P "  },"
    print -P "  \"rust\": {"
    print -P "    \"windows\": 2,"
    print -P "    \"commands\": {"
    print -P "      \"1\": [\"nvim src/main.rs\"],"
    print -P "      \"2\": [\"cargo watch -x run\"]"
    print -P "    },"
    print -P "    \"search_dirs\": [\"~/Projects/rust\"]"
    print -P "  },"
    print -P "  \"js\": {"
    print -P "    \"windows\": 2,"
    print -P "    \"commands\": {"
    print -P "      \"1\": [\"nvim\"],"
    print -P "      \"2\": [\"npm start\"]"
    print -P "    }"
    print -P "  }"
    print -P "}${RESET}"


    print -P ""
    print -P "${GREEN}🛠  Dependencies:${RESET} ${CYAN}tmux, fzf, jq, fd, eza${RESET}"
    print -P ""
    print -P "${GREEN}💡 Tip:${RESET} You can use templates to define different project types, and override them per session using ${CYAN}-t${RESET} flag."
    print -P ""
}

