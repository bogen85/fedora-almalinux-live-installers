#!/bin/bash
# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail
export BASHOPTS SHELLOPTS
sudo=sudo

function prep_root () {
  local _root_src=$1
  local _root=$2
  if [ -d "$root" ]; then
    $sudo rm -rf $_root/*
    $sudo umount $_root -Rv || true
    $sudo rm -rf $_root $_root_src
  fi

  $sudo mkdir -pv $_root_src $_root
  $sudo mount -v -o bind $_root_src $_root

  hqus=/home/qemu-user-static/
  $sudo mkdir -pv $_root/$hqus $_root/etc
  $sudo rsync -av /run/host/$hqus $_root/$hqus

  $sudo cp -v /etc/resolv.conf $_root/etc/resolv.conf.00
}

function _arch_chroot () {
  local _root=${1}; shift
  $sudo rm -vf $root/etc/resolv.conf
  local cmd=$@
  if [ "$arch" == "i386" ]; then
    local pre="setarch i386"
  else
    local pre=""
  fi

  $sudo tee $root/root/script << __END__
    set -euo pipefail;
    hostname $hostname;
    cp -v /etc/resolv.conf.00 /etc/resolv.conf;
    $pre $cmd
__END__

  $sudo arch-chroot $root sh /root/script
  $sudo rm -vf $root/etc/resolv.conf
}

function arch_chroot () { _arch_chroot $@; }

function bootstrap () {
  prep_root $root_src $root

  local pkg1=$1
  local pkg2=$(echo -n $2)
  packages=$@

  $sudo apk --arch $alpine_arch \
    -X http://dl-cdn.alpinelinux.org/alpine/$flavor/main/ \
    -X http://dl-cdn.alpinelinux.org/alpine/$flavor/community/ \
    -U --allow-untrusted --root $root --initdb add $pkg1

  echo "$repos" | $sudo tee $root/etc/apk/repositories

  arch_chroot $root setup-hostname "$hostname"
  arch_chroot $root apk update
  arch_chroot $root apk upgrade
  [ "" == "$pkg2" ] || arch_chroot $root apk add $pkg2
}

packages1=$(echo $(cat <<__END__
  setarch bash alpine-base
  bash-completion
  clang
  czmq-dev
  fakeroot
  g++
  gcc
  git
  htop
  joe
  make
  mosquitto-dev
  openssh-client-default
  pkgconf
  python3-dev
  micro
  mlocate
  qt6-qtbase-dev
__END__
))" "

packages2=$(echo $(cat <<__END__
__END__
))" "

export arch=$1

arches="x86_64 i386 armhf ppc64le armv7 aarch64 riscv64"
root_src=/mnt/bootstraps/alpine-$arch-test
root=$root_src.mnt

export alpine_arch=$arch
export flavor=latest-stable

case $arch in
  armhf | armv7 | aarch64 | x86_64)
    packages2+="fpc"
    ;;
  i386)
    export alpine_arch=x86
    packages2+="fpc"
    ;;
  ppc64le)
    packages2+="fpc-stage0"
    ;;
  riscv64)
    echo WIP: $arch
    export flavor=edge
    ;;
  *)
    echo Invalid arch: $arch
    echo Valid arches: $arches
    exit 1
    ;;
esac

shift

export hostname=alpine-$arch-test10
export repos=$(cat << __END__
https://dl-cdn.alpinelinux.org/alpine/$flavor/main
https://dl-cdn.alpinelinux.org/alpine/$flavor/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
__END__
)

args=$@

if [ "$args" == "" ]; then
  cmd="none"
else
  cmd=$1
  shift
  _args=$@
fi

case "$cmd" in
  chroot)
    [ "$_args" == "" ] && _args="bash"
    arch_chroot $root $_args
    ;;
  init)
    bootstrap "$packages1" "$packages2"
    ;;
  *)
    echo provided: $cmd
    echo must provide a valid command
    exit 1
    ;;
esac
