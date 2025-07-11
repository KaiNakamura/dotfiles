# TODO: Not actually real yet, need to figure out how to do .zshrc without overwriting current

plugins=(
	git
)

# Starship
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# Neovim
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
