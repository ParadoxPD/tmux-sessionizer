# 🧠 tmux-sessionizer

A productivity-enhancing Zsh-based utility for managing `tmux` sessions with templates, directory search, project-local configs, and custom window setups. Supercharged with `fzf`, `jq`, and `fd`.

## 📌 Features

- Attach to existing sessions quickly
- Create structured `tmux` sessions with multiple windows
- Define custom project templates via JSON config
- Local (per-project) config support
- Search for directories using `fzf + fd`
- Clean and colorful `--help` output
- Works well as a project launcher and terminal workspace manager

## ⚙️ Requirements

Ensure the following tools are installed:

- [tmux](https://github.com/tmux/tmux)
- [fzf](https://github.com/junegunn/fzf)
- [jq](https://stedolan.github.io/jq/)
- [fd](https://github.com/sharkdp/fd)
- [eza](https://github.com/eza-community/eza) (for preview tree view)

## 📁 Installation

Clone or copy the script into your dotfiles or source it from `.zshrc`:

```sh
source /path/to/tmux-sessionizer.zsh
```

Optionally set a global config path:

```sh
export TMUX_CONF_DIR="$HOME/.config/tmux"
```

## 🧪 Commands

### 🔹 `ta [session_name]`

Attach to an existing tmux session by name or just attach if only one session exists.

```sh
ta               # Attach to the last active session
ta dev-session   # Attach to 'dev-session'
```

---

### 🔹 `tn [options] <session_name>`

Create and attach to a `tmux` session with optional window/template overrides.

```sh
tn my-session                    # Use default template
tn -n 4 -c "nvim ." my-session   # 4 windows, run nvim in the first
tn -t rust my-session            # Use the 'rust' template from config
```

**Options:**

- `-n`, `--num-windows`: Override number of windows
- `-c`, `--command`: Command to run in a window (repeatable)
- `-t`, `--template`: Use a specific template

---

### 🔹 `tl`

List all tmux sessions using `fzf` and attach to the selected one.

---

### 🔹 `tk`

List all tmux sessions using `fzf` and kill the selected session.

---

### 🔹 `t [options]`

Search for a directory using `fzf` (within defined `search_dirs`), then:

- `cd` into that directory
- Create a session named after the folder
- Use the specified or default template to spawn windows + run commands

**Options:**

- `-n`, `--num-windows`: Override number of windows
- `-c`, `--command`: Command to run in a window (repeatable)
- `-t`, `--template`: Use a specific template

```sh
t
t -t rust  # Use 'rust' template while picking a folder
```

---

### 🔹 `thelp`

Show full command usage in color with examples.

---

## ⚙️ Configuration

### 🔸 Global Config Path

Defaults to:

```text
$XDG_CONFIG_HOME/tmux/.tmux.sessionizer.json
# or
$HOME/.config/tmux/.tmux.sessionizer.json
```

### 🔸 Local Config Support

Place a `.tmux.sessionizer.json` in any project root to override the global one.

---

### 🧾 Config File Structure

```json
{
  "defaults": {
    "windows": 3,
    "commands": ["nvim", "htop", "git status"],
    "search_dirs": ["~/Documents", "~/Desktop"]
  },
  "rust": {
    "windows": 2,
    "commands": ["nvim src/main.rs", "cargo watch -x run"],
    "search_dirs": ["~/Projects/rust"]
  },
  "js": {
    "windows": 2,
    "commands": ["nvim", "npm start"]
  }
}
```

**Keys:**

- `windows`: Number of windows to open in the session
- `commands`: Commands to run in windows (`commands[0]` → window 1, etc.)
- `search_dirs`: Used by `t` command to search for project folders

---

## 🧠 Tips

- You can define templates like `"node"`, `"go"`, `"elixir"` to bootstrap new sessions.
- Create a `.tmux.sessionizer.json` in a project to set up isolated environments.
- Use `-c` multiple times to send different commands to different windows.

---

## 📌 Example Workflows

```sh
# Launch a rust dev session from anywhere
t -t rust

# Start a new session with default config
tn my-app

# Quickly jump to an existing session
tl

# Kill a stuck session
tk
```

---

## 🤯 Why?

This tool helps you instantly jump into a tmux-powered dev environment with:

- Preloaded editors
- Build/watch commands
- Shell tools
- A clean structure

All from a single command.

---

## Inspiration

This project is heavily inspired by ThePrimeagen, whose tmux workflow and productivity content are second to none.
If you like this tool, go check out his streams, dotfiles, and content — it's a goldmine.

---

## 🧑‍💻 Author

Built with ❤️ by Paradox — designed for developers who live in the terminal.
