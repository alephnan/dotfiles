#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Start from the full default colour database (extension rules for .zip, .jpg,
# .tar, ... live here) and patch on top of it -- assigning LS_COLORS directly
# would throw all of that away and fall back to ls's compiled-in defaults.
eval "$(dircolors -b)"

# DrvFs (/mnt/c/...) reports every dir as world-writable (777), which makes
# GNU ls highlight them with a jarring blue-on-green background. Fall back
# to plain bold-blue like a normal directory.
LS_COLORS+=":ow=01;34:tw=01;34:st=01;34"

# Without the `metadata` mount option DrvFs also fakes the exec bit on every
# file, so the `ex` rule paints the whole of /mnt/c green. Neutralise `ex`
# only while that is the case; once /etc/wsl.conf's metadata option is live
# (after a `wsl --shutdown`) real executables colour correctly again.
grep -q '^[^ ]* /mnt/c .*metadata' /proc/mounts || LS_COLORS+=":ex=00"

export LS_COLORS
PS1='[\u@\h \W]\$ '

# >>> Codex installer >>>
export PATH="/home/alephnan/.local/bin:$PATH"
# <<< Codex installer <<<

# Starship prompt (catppuccin-powerline preset -> ~/.config/starship.toml)
# Requires a Nerd Font in the terminal for the powerline separators/icons.
eval "$(starship init bash)"
