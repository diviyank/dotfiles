set -gx EDITOR emacs
set fish_greeting #"Hello Diviyan ! What are you going to break today ?"
fzf_configure_bindings --directory=\ce
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND "--type=f"
set -gx FZF_CTRL_T_OPTS "--preview='bat --style=numbers --color=always {}'"
set -gx FZF_ALT_C_COMMAND $FZF_DEFAULT_COMMAND "--type=d"
alias py xonsh

starship init fish | source
pyenv init - | source
fish_add_path /home/diviyan/.emacs.d/bin
source $HOME/.grit/bin/env.fish
set --export GRIT_INSTALL "$HOME/.grit"
set --export PATH $GRIT_INSTALL/bin $PATH
function gp --description "grit python"
    command grit apply "language python $argv"
end
zoxide init --cmd cd fish | source
