#!/bin/sh
#

p="${DON_PATH:-$HOME/.config/etcdon}"

echo "Welcome to etcdon!"
echo "If you have an existing crontab you want to keep, use ctrl-c to exit"
echo "If you don't know what a crontab is you're all set!"
echo
echo -n "What is the hostname or IP address of your server? "
read -r server
echo    "Writing $server to local/server"
echo -n "$server" > "$p"/local/server

mkdir -p ~/.config

if [ -z ~/.config/etcdon ]; then
    echo "Cloning etcdon into ~/.config/etcdon"
    git clone https://github.com/fuzz/etcdon.git ~/.config/etcdon
else
    echo "etcdon exists, skipping--use 'rm -rf ~/.config/etcdon' to remove"
fi

sudo ln -vfs ~/.config/etcdon/bin/don /usr/local/bin/
/usr/local/bin/don install-crontab-postgres
/usr/local/bin/don gather-secrets
echo "Last chance to ctrl-c to exit before I overwrite your crontab, you have"
echo "ten seconds. If you don't know what this is it doesn't apply to you :)"
sleep 10
crontab "$p"/etc/crontab-local
echo "Unless you see any errors above, congratulations!"
