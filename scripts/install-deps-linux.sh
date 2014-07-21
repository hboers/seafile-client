#!/bin/bash
set -x

sudo add-apt-repository -y ppa:george-edison55/cmake-precise
sudo add-apt-repository -y ppa:beineri/opt-qt54
sudo apt-get update -qq
sudo apt-get install -qq valac uuid-dev libevent-dev re2c libjansson-dev cmake libqt4-dev
sudo apt-get install -qq qt54base qt54translations qt54tools qt54webkit

git clone --depth=1 --branch=master git://github.com/haiwen/libsearpc.git deps/libsearpc
git clone --depth=1 --branch=master git://github.com/haiwen/ccnet.git deps/ccnet
git clone --depth=1 --branch=master git://github.com/haiwen/seafile.git deps/seafile
pushd deps/libsearpc
./autogen.sh && ./configure
make -j8 && sudo make install
popd

pushd deps/ccnet
./autogen.sh && ./configure --enable-client --disable-server
make -j8 && sudo make install
popd

pushd deps/seafile
./autogen.sh && ./configure --disable-fuse --disable-server --enable-client
make -j8 && sudo make install
popd
