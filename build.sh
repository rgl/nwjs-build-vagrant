#!/bin/bash
set -eux

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive
apt-get update


#
# provision vim.

apt-get install -y --no-install-recommends vim

cat >~/.vimrc <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# provision git.

apt-get install -y --no-install-recommends git
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple


#
# enable wget quiet mode (to disable the process bar).

echo 'quiet=on' >~/.wgetrc


#
# configure the shell.

cat >~/.bash_history <<'EOF'
EOF

cat >~/.bashrc <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >~/.inputrc <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF


#
# install tools.
# see http://docs.nwjs.io/en/latest/For%20Developers/Building%20NW.js/
# see https://github.com/nwjs/nw.js/issues/7111
# see http://buildbot-master.nwjs.io:8010/builders/nw39_linux64/
# see http://buildbot-master.nwjs.io:8010/builders/nw39_win64/

apt-get install -y python # this installs python 2.7.
cd $HOME
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PATH:$PWD/depot_tools"
echo 'export PATH="$PATH:$PWD/depot_tools"' >>~/.bashrc


#
# get the code and install dependencies.

mkdir -p nwjs
cd nwjs
gclient config --name=src https://github.com/nwjs/chromium.src.git@origin/nw39
git clone -b nw39 https://github.com/nwjs/nw.js.git src/content/nw
git clone -b nw39 https://github.com/nwjs/node.git src/third_party/node-nw
git clone -b nw39 https://github.com/nwjs/v8.git src/v8
gclient sync --with_branch_heads
./build/install-build-deps.sh


#
# build.

cd src
gn gen out/nw \
    '--args=is_debug=false is_component_ffmpeg=true target_cpu="x64" symbol_level=1 is_component_build=false nwjs_sdk=false ffmpeg_branding="Chromium"'
GYP_CHROMIUM_NO_ACTION=0 \
GYP_DEFINES="target_arch=x64 building_nw=1 clang=1 buildtype=Official" \
GYP_GENERATORS=ninja \
    ./build/gyp_chromium \
        -I third_party/node-nw/common.gypi \
        third_party/node-nw/node.gyp
GYP_CHROMIUM_NO_ACTION=0 \
GYP_DEFINES="target_arch=x64 building_nw=1 clang=1 buildtype=Official" \
GYP_GENERATORS=ninja \
    ninja -C out/nw nwjs
ninja -C out/Release node
ninja -C out/nw copy_node
ninja -C out/nw dump
GYP_CHROMIUM_NO_ACTION=0 \
GYP_DEFINES="target_arch=x64 building_nw=1 clang=1 buildtype=Official" \
GYP_GENERATORS=ninja \
    ninja -C src/outst/nw dist
