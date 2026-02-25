# 🧙‍♂️ Alias Master

Alias Master is a smart Zsh plugin that coaches you to actually use your aliases. It gives you live hints while you type, reminds you if you forget to use a shortcut, and can even force you to use them! 

---

## 🚀 Installation

Since this is a proper Zsh plugin, we'll install it right into your Oh My Zsh custom plugins folder. It's super easy!

**1. Clone the repository:**
Fire up your terminal and clone the repo into your custom plugins directory:
```zsh
git clone https://github.com/YOUR_USERNAME/alias-master.git $ZSH/custom/plugins/alias-master
```

**2. Enable the plugin:**
Open your `~/.zshrc` file, find the `plugins=(...)` array, and add `alias-master` to the list. 
*(Make sure to put it at the end, or at least after the plugins that define your aliases!)*
```zsh
plugins=(
  git
  docker
  # ... other plugins ...
  alias-master
)
```

*(Not using Oh My Zsh? No worries! Just add `source ~/.zsh/custom/plugins/alias-master/alias-master.plugin.zsh` manually to your `.zshrc`)*

**3. Reload your terminal:**
run `source ~/.zshrc`

**4. Close and open your terminal (optional): ** It's highly recommended to just close your terminal completely and open a fresh one. This guarantees the caching system and background jobs kick in perfectly! 🎉

---

## ✨ Features (What does it do?)

### 1. 🚦 Live Reverse Hinting
Start typing a full command. If you have an alias for it, Alias Master will quietly pop up a hint right below your cursor.
*   **You type:** `git status`
*   **Hint shows:** `💡 alias: gst`

### 2. ⏩ Live Forward Hinting
Forgot what an obscure alias actually does? Just type it, and it will show you the expanded command before you hit enter.
*   **You type:** `gco`
*   **Hint shows:** `=> git checkout`

### 3. 🛑 Post-Execution Reminder
If you ignore the live hint and hit `Enter` on a full command anyway, the plugin will print a friendly reminder *after* the command runs.
*   **Message:** `💡 existing alias for "git status": "gst"`

### 4. 🧠 Smart Git Integration
It automatically reads your `~/.gitconfig` aliases in the background (asynchronously) and adds them to the hint system without slowing down your terminal's startup time.

---

## ⌨️ Keyboard Shortcuts (Mute the hints)

Sometimes you just want to type the full command without being bothered. You can toggle hints on and off instantly. **Bonus:** It remembers your choices even after you reboot (saves to `~/.alias_master_prefs`).

*   **`Alt + h` (Toggle Local):** Disables/Enables the hint for the **specific command/alias** you are currently typing.

---

## 🧰 Built-in Tools

We packed two extra commands to help you manage your workflow:

*   **`als`**: Takes all your aliases (and Git aliases) and pipes them into a beautiful, searchable Python cheatsheet. *(Note: make sure `cheatsheet.py` is in the same folder as the plugin).*
*   **`check_alias_usage`**: Ever wondered which aliases you actually use? Run this command! It scans your Zsh history and prints a ranked list of your most and least used aliases.

---

## ⚙️ Customization & Options

You can tweak how Alias Master behaves by setting these variables in your `~/.zshrc` (put them *before* your `plugins=(...)` array):

### 😈 Hardcore Mode
Want to force yourself to learn your aliases? Turn this on. If you type a full command when an alias exists, Alias Master will yell at you and **kill the command**. 
```zsh
export ALIAS_MASTER_HARDCORE=1
```
*(Only want hardcore mode for specific aliases? Do this instead: `export ALIAS_MASTER_HARDCORE_ALIASES=('gst' 'gco')`)*

### 🙈 Ignore Specific Aliases
Got some aliases you don't want Alias Master to nag you about? Add them to the ignore list:
```zsh
export ALIAS_MASTER_IGNORED_ALIASES=('ls' 'll' 'grep')
export ALIAS_MASTER_IGNORED_GLOBAL_ALIASES=('G' 'L')
```

### 📍 Message Position
By default, the post-execution warning shows up *before* the command output. If you want it to show up *after* the output:
```zsh
export ALIAS_MASTER_MESSAGE_POSITION="after"
```

---

## 🐛 Found a bug? 
Feel free to open an issue or drop a pull request. Let's make the terminal a better place together! 💻✨