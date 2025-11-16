plugins=(
	git
)

# Starship
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"
# alias cd="z"

# Neovim
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
