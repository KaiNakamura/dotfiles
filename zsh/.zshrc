# TODO: Not actually real yet, need to figure out how to do .zshrc without overwriting current

plugins=(
	git
)

# zoxide
eval "$(zoxide init zsh)"
alias cd="z"
