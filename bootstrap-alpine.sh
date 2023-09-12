#!/bin/bash
# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail
export BASHOPTS SHELLOPTS
sudo=sudo
export rootfs_tarballs=/run/host/home/alpine-qemu-rootfs-tarballs

valid_cmds="chroot tar tar-built tar-all init init-all ls rm rm-all arch help -h --help"

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
      usage "$item <arch>
        enter chroot for <arch>, initialize if no root for <arch> exists"
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
    init-all)
      usage "$item
        create roots for all available architectures"
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


function _ls_roots () {
  for r in /mnt/bootstraps/alpine-*-test.mnt; do
    echo $(basename $r) | sed -e 's/^alpine-//' -e 's/-test.mnt$//'
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
    $sudo umount $_root -Rv || true
    $sudo rm -rf $_root $_root_src
  fi
}

function prep_root () {
  local _root_src=$1
  local _root=$2

  rm_root $1 $2

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
  if [ "$arch" == "x32" ]; then
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

function check_target_root () {
  if [ -f $root/etc/hostname ]; then
    :
  else
    bootstrap "$packages1" "$packages2"
  fi
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

__packages2__=$(echo $(cat <<__END__
__END__
))" "
export packages2=""

arches="aarch64 armhf armv7 ppc64le riscv64 x32 x64"

function setup_arch () {
  local _invalid_ok=$@
  [ "$_invalid_ok" == "" ] && _invalid_ok=no

  export root_src=/mnt/bootstraps/alpine-$arch-test
  export root=$root_src.mnt

  export alpine_arch=$arch
  export flavor=latest-stable
  export packages2=$__packages2__
  case $arch in
    armhf | armv7 | aarch64)
      packages2+="fpc"
      ;;
    x64)
      export alpine_arch=x86_64
      packages2+="fpc"
      ;;
    x32)
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
      [ "$_invalid_ok" == "no" ] && exit 1 || true
      ;;
  esac

  export packages1 packages2
  export hostname=alpine-$arch-test10
  export repos=$(sed -e 's/ //g' << __END__
    https://dl-cdn.alpinelinux.org/alpine/$flavor/main
    https://dl-cdn.alpinelinux.org/alpine/$flavor/community
    https://dl-cdn.alpinelinux.org/alpine/edge/testing
__END__
);}

function get_arch () {
  local _args=$@
  if [ "$_args" == "" ]; then
    echo Missing "<ARCH>" for $cmd
    show_item_help $cmd
    exit 1
  else
    arch=$_args
    setup_arch $invalid_ok
  fi
}

function rm_one () {
  invalid_ok=yes
  get_arch $@
  rm_root $root_src $root
}

function tar_one () {
  get_arch $@
  check_target_root
  sudo bash -c '
    set -euo pipefail;
    mkdir -pv '${rootfs_tarballs}'
    tar='${rootfs_tarballs}'/$(basename '${root_src}'.tar);
    rm -f $tar; set -x;
    cd '${root_src}';
    tar cf $tar .;
    du -h $tar;
  '
}

args=$@
script=$0
arch="unknown"

if [ "$args" == "" ]; then
  cmd="none"
else
  cmd=$1
  shift
fi

invalid_ok="no"

case "$cmd" in
  -h | help | --help)
    _cmd=$@
    show_help "$_cmd"
    ;;
  arch)
    echo arches: $arches
    ;;
  chroot)
    get_arch $@; shift; args=$@
    check_target_root
    [ "$args" == "" ] && args="bash"
    arch_chroot $root $args
    ;;
  tar)
    tar_one $@
    ;;
  tar-built)
    for _arch in $(ls_roots); do tar_one $_arch; done
    ;;
  tar-all)
    for _arch in $arches; do tar_one $_arch; done
    ;;
  init)
    get_arch $@; shift; args=$@
    bootstrap "$packages1" "$packages2"
    ;;
  init-all)
    for _arch in $arches; do
      get_arch $_arch
      bootstrap "$packages1" "$packages2"
    done
    ;;
  ls)
    printf 'built : %s\n' "$(ls_roots)"
    ;;
  rm)
    rm_one $@
    ;;
  rm-all)
    for _arch in $(ls_roots); do rm_one $_arch; done
    ;;
  *)
    echo cmd provided: $cmd
    show_help
    exit 1
    ;;
esac
