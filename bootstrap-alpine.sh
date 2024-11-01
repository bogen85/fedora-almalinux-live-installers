#!/bin/bash
# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail
export BASHOPTS SHELLOPTS
sudo=sudo
apk=$(which apk)
bootstraps=/mnt/bootstraps

export rootfs_tarballs=/run/host/home/alpine-qemu-rootfs-tarballs
rootname_prefix="alpine-"
rootname_suffix="-test"

valid_cmds="chroot tar tar-built tar-all init redo-init init-all init-missing ls rm rm-all arch help -h --help"
arches="aarch64 armhf armv7 ppc64le riscv64 x32 x64"

repo_root_url=https://dl-cdn.alpinelinux.org/alpine

packages1=$(echo -n $(echo -n "
  setarch alpine-base
  czmq-dev
  fakeroot
  git
  make
  mosquitto-dev
  pkgconf
  micro
  mlocate
"))

__packages2__=$(echo -n $(echo -n "
  bash
  bash-completion
  joe
  htop
  openssh-client-default
  clang
  g++
  gcc
  qt6-qtbase-dev
  python3-dev
"))

export packages2=""


function usage () {
  echo "usage: $script $@"
}

function show_help_help () {
  local item=$@
  usage "$item <cmd>
        help for cmd, one of: $valid_cmds"
  usage "$item
        this help"
}

function show_item_help () {
  local item=$@
  case "$item" in
    -h | help | --help)
      show_help_help $@
      ;;
    arch)
      usage "$item
        show avaliable architectures"
      ;;
    chroot)
      usage "$item <arch> [command string]
        enter chroot for <arch>, initialize if no root for <arch> exists
        if command string it given it is executed in the chroot instead of a shell"
      ;;
    tar)
      usage "$item <arch>
        make tarball for <arch>, initialize if no root for <arch> exists"
      ;;
    tar-built)
      usage "$item
        make tarballs for architectures that have roots built"
      ;;
    tar-all)
      usage "$item
        make tarballs for all available architectures, initializing the roots as needed"
      ;;
    init)
      usage "$item <arch>
        create root for given architecture"
      ;;
    redo-init)
      usage "$item
        recreate roots for architectures with existing roots"
      ;;
    init-all)
      usage "$item
        create roots for all available architectures"
      ;;
    init-missing)
      usage "$item
        create roots for all available architectures with missing roots"
      ;;
    ls)
      usage "$item
        list architectures with initialized roots"
      ;;
    rm)
      usage "$item <arch>
        remove root for given architecture"
      ;;
    rm-all)
      usage "$item <arch>
        remove initialized roots for all architectures"
      ;;
    *)
      echo "unknown command: $item"
      show_help_help help
      exit 1
      ;;
  esac
}

function show_help () {
  local item=$@
  if [ "$item" == "" ]; then
    usage "<cmd>
        where cmd is one of: $valid_cmds"
    show_item_help help
    return
  fi
  show_item_help $item
}

function mkrootname () {
  local _arch=$@
  [ "$_arch" == "" ] && _arch='*'
  printf ${rootname_prefix}'%s'${rootname_suffix} "$_arch"
}

function _ls_roots () {
  local r
  for r in $(eval "echo -n $bootstraps/$(mkrootname).mnt"); do
    basename $r \
      | sed -e 's/^'${rootname_prefix}'//' -e 's/'${rootname_suffix}'.mnt$//'
  done
}

function ls_roots () {
  local _arches=$(_ls_roots)
  [ "$_arches" == "*" ] || echo $_arches
}

function rm_root () {
  local _root_src=$1
  local _root=$2
  if [ -d "$_root" ]; then
    if ! $sudo umount -Rv  $_root  ; then
         $sudo umount -Rvl $_root || true
    fi
    $sudo rm -rf  $_root/* $_root_src/*
    $sudo rm -rfv $_root/  $_root_src/
  fi
}

function prep_root () {
  local _root_src=$1
  local _root=$2

  rm_root $1 $2

  $sudo mkdir -pv $_root_src $_root
  $sudo mount -v -o bind $_root_src $_root

  hqus=home/qemu-user-static/
  $sudo mkdir -pv $_root/$hqus $_root/etc
  $sudo rsync -av /run/host/$hqus $_root/$hqus

  $sudo cp -v /etc/resolv.conf $_root/etc/resolv.conf.00
}

function _arch_chroot () {
  local _root=${1}; shift
  $sudo rm -vf $root/etc/resolv.conf
  local cmd=$@
  if [ "$arch" == "x32" ]; then
    local pre="setarch linux32"
  else
    local pre=""
  fi

  echo "set -euo pipefail
    hostname $hostname
    cp -v /etc/resolv.conf.00 /etc/resolv.conf
    exec $pre $cmd" | sed 's/^ */  /' | $sudo tee $root/root/script

  function cleanup () {
    $sudo rm -vf $root/etc/resolv.conf $root/root/script
  }

  if $sudo arch-chroot $root sh /root/script; then
    cleanup
  else
    cleanup
    exit 1
  fi
}

function arch_chroot () { _arch_chroot $@; }

function bootstrap () {
  prep_root $root_src $root

  local pkg1=$packages1
  local pkg2=$packages2

  $sudo $apk --arch $alpine_arch \
    -X $repo_root_url/$flavor/main/ \
    -X $repo_root_url/$flavor/community/ \
    -U --allow-untrusted --root $root --initdb add $pkg1

  printf '%s\n' $repos | $sudo tee $root/etc/apk/repositories

  arch_chroot $root setup-hostname $hostname

  local auu="'apk update --quiet && apk upgrade'"
  arch_chroot $root sh -c "$auu"
  [ "" == "$pkg2" ] || arch_chroot $root apk add $pkg2
  arch_chroot $root sh -c "$auu"
}

function setup_arch () {
  export arch=$@

  export root_src=$bootstraps/$(mkrootname $arch)
  export root=$root_src.mnt

  export alpine_arch=$arch
  export flavor=latest-stable
  packages2=$__packages2__
  case $arch in
    armhf | armv7 | aarch64)  packages2+=" fpc";;

    x64)  packages2+=" fpc"; export alpine_arch=x86_64;;
    x32)  packages2+=" fpc"; export alpine_arch=x86;;

    ppc64le)  packages2+=" fpc-stage0" ;;
    riscv64)  echo WIP: $arch;  export flavor=edge;;

    *) printf 'Invalid arch: %s\nValid: %s\n' "$arch" "$arches"; exit 1;;
  esac

  packages2=$(echo -n $packages2)
  export packages1 packages2
  export hostname=$(mkrootname $arch)10

  export repos="
    $repo_root_url/$flavor/main
    $repo_root_url/$flavor/community
    $repo_root_url/edge/testing"
}

function get_arch () {
  local _args=$@
  if [ "$_args" == "" ]; then
    echo Missing "<ARCH>" for $cmd
    show_item_help $cmd
    exit 1
  fi
  setup_arch $_args
}

function check_target_root () {
  get_arch $@
  local _hostname=$root_src/etc/hostname
  if [ -f $_hostname ]; then
    cat $_hostname
  else
    bootstrap
  fi
}

function rm_one () {
  get_arch $@
  rm_root $root_src $root
}

function tar_one () {
  local _arch=$@
  get_arch $_arch
  check_target_root $_arch
  sudo bash -c '
    set -euo pipefail;
    mkdir -pv '${rootfs_tarballs}'
    tar='${rootfs_tarballs}'/$(basename '${root_src}'.tar);
    rm -f $tar; set -x;
    cd '${root_src}';
    tar cpf $tar .;
    du -h $tar;
  '
}

function init_one () {
  get_arch $@
  bootstrap
}

function check_one () {
  local _arch=$@
  get_arch $_arch
  check_target_root $_arch
}

function _ls () {
  printf 'built : %s\n' "$(ls_roots)"
}

function for_archs () {
  local fun=$1
  shift
  local _arches=$@
  local _arch
  for _arch in $_arches; do $fun $_arch; done
}

function chroot_one () {
  local _arch=$1; shift
  local _args=$@
  check_target_root $_arch
  [ "$_args" == "" ] && local _args="bash"
  arch_chroot $root $_args
}

function main() {
  local args=$@
  export script=$0
  export arch="unknown"

  if [ "$args" == "" ]; then
    local cmd="none"
  else
    local cmd=$1; shift; local args=$@
  fi

  case "$cmd" in
    -h | help | --help) local cmd=$@; show_help "$cmd";;

    tar) tar_one $@;;
    init) init_one $@;;
    ls) _ls;;
    rm) rm_one $@;;

    arch) echo arches: $arches;;

    init-all)     for_archs "init_one"   $arches;;
    tar-all)      for_archs "tar_one"    $arches;;
    init-missing) for_archs "check_one"  $arches;;

    rm-all)       for_archs "rm_one"     $(ls_roots);;
    redo-init)    for_archs "init_one"   $(ls_roots);;
    tar-built)    for_archs "tar_one"    $(ls_roots);;

    chroot)
      [ "$args" == "" ] && get_arch ""
      local _arch=$1; shift
      chroot_one $_arch $@
      ;;

    *) echo cmd provided: $cmd; show_help; exit 1;;
  esac
}

main $@
