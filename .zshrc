# Path to your oh-my-zsh installation.
export ZSH=/root/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git docker)

# User configuration
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
#export LANG=en_US.UTF-8
#
# Example aliases
#
alias zshconfig="mate ~/.zshrc"
alias ohmyzsh="mate ~/.oh-my-zsh"
# Alias to mount external FTP backup volume
alias ftpmount="curlftpfs USER:PASS@HOST:21 /mnt/ftpbackup/"
# Alias for pretty docker ps output
alias dps="docker ps --format \"table{{.Names}}\\t{{.Image}}\\t{{.Ports}}\\t{{.Status}}\""
alias dpsa="docker ps --format \"table{{.Names}}\\t{{.Image}}\\t{{.Ports}}\\t{{.Status}}\" -a"
