set -gx EDITOR emacs
set fish_greeting #"Hello Diviyan ! What are you going to break today ?"
# Set up fzf key bindings
set -U fish_user_paths /opt/homebrew/bin $fish_user_paths
fzf --fish | source
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND "--type=f"
set -gx FZF_CTRL_T_OPTS "--preview='bat --style=numbers --color=always {}'"
set -gx FZF_ALT_C_COMMAND $FZF_DEFAULT_COMMAND "--type=d"
alias enw "emacs -nw"
alias ga "git add -u"
alias gc "git commit -m"
alias gp "git push"
alias gf "git pull"
alias gcb "git checkout -b"
alias gs "git status"
alias gd "git diff HEAD"
function gtag --description "git tag and push"
   command git tag $argv && git push origin $argv
end
function gcp --description "git commit and push"
   command git commit -m $argv && git push
end

starship init fish | source
pyenv init - | source
fish_add_path /home/diviyan/.emacs.d/bin
zoxide init --cmd cd fish | source
