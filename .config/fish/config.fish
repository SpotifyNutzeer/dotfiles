if status is-interactive
# Commands to run in interactive sessions can go here
end
export PATH="$HOME/.local/bin:$PATH"
starship init fish | source
export DOCKER_HOST=unix:///run/user/1000/docker.sock
