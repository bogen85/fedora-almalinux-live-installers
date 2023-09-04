#!/bin/bash
# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail
export BASHOPTS SHELLOPTS

function configure() {
  conf=bootstrap-conf
  source $conf/common.conf
  $sudo -v
}

function bootstrap_main () {
  $sudo rpmdb --root $root --initdb
  $sudo rpm --root $root -ivh $rpms
  $sudo systemd-machine-id-setup --root=$root

  if ! [ -f "$rpm_gpg_key" ]; then
    $sudo rm -vf $rpm_gpg_key
    $sudo mkdir -pv $(dirname $rpm_gpg_key)
    $sudo cp -iv $root/$rpm_gpg_key $rpm_gpg_key
  fi

  use_parent_resolv_conf

  $bash "printf 'LANG=en_US.UTF-8\nLC_MESSAGES=C\n' > /etc/locale.conf"

  $dnf0 install $pkg0
  to_dnf_conf 'install_weak_deps=False'
  to_dnf_conf 'exclude=java-* *-java* *jdk* javapackages-* yum'

  $bash 'rpmdb --rebuilddb'

  $dnf1 install $pkg1
  $dnf2 remove $pkg0

  $chroot cat /etc/os-release
  $chroot cat /etc/dnf/dnf.conf
}

function format_vars() {
  local prefix=$1
  shift
  printf "$prefix"' %s=%s;\n' "$@"
}

function root() {
  local root_src=$root_prefix/$distro-$release-$arch

  if [ "$1" == "done" ]; then
    mount | grep -F $root_src
    return
  fi

  function prep_root () {
    local root=$1
    if [ -d "$root" ]; then
      $sudo rm -rf $root/*
      $sudo umount $root -v || true
      $sudo rm -rf $root $root_src
    fi

    $sudo mkdir -pv $root_src $root
    $sudo mount -v -o bind $root_src $root
  }

  function prep_root_vars () {
    local root=$2.mnt

    1>&2 prep_root $root

    local chroot="$sudo chroot "$root
    local achroot="$sudo arch-chroot "$root
    local _dnf="dnf -y --setopt=install_weak_deps="
    local dnf0="${_dnf}False"
    local dnf1="${_dnf}0"

    format_vars $1 \
      root "'$root'" \
      dnf0 "'$sudo $dnf0 --installroot=$root'"  \
      dnf1 "'$achroot micro$dnf1'" \
      dnf2 "'$achroot $dnf0'" \
      bash "'$chroot bash -c'" \
      chroot "'$chroot'"
  }
  prep_root_vars $1 $root_src
}

function get_rpms() {

  local rpms=""
  function download_rpms () {
    function download_rpm () {
      local pr1=$1
      local pr2=$2
      rm -vf $pr2
      if ! wget $base_packages/$pr1 -O$pr2; then
        rm -vf $pr2
        exit 1
      fi
    }

    local _rpms=$1
    [ "$_rpms" == "" ] && return
    local suffix=$2
    for _rpm0 in $_rpms; do
      local _rpm=$_rpm0.$suffix
      local rpm=$rpms_dest/$_rpm
      [ -s $rpm ] || download_rpm $_rpm $rpm
      rpms+=" $rpm"
    done
  }

  1>&2 mkdir -pv $rpms_dest
  1>&2 download_rpms "$2" $arch.rpm
  1>&2 download_rpms "$3" $tag.noarch.rpm
  1>&2 download_rpms "$4" $dist.noarch.rpm

  format_vars $1 rpms "'$rpms'"
}

function use_parent_resolv_conf() {
  $sudo rm -vf $root/etc/resolv.conf
  cat /etc/resolv.conf | $sudo dd of=$root/etc/resolv.conf
}


function bootstrap() {

  function to_dnf_conf() {
    $bash "printf '$1\n' >> /etc/dnf/dnf.conf"
  }

  local release=$1
  base_packages=$package_mirror/$distro/$release/$baseroot/$arch/$os_packages

  source $conf/$distro-$release.conf

  function get_vars() {
    local prefix=':::'
    local match="^$prefix..*=..*;"
    local vars0=$(get_rpms $prefix "$_r0" "$_r1" "$_r2")
    local vars1=$(root $prefix)
    local raw=$(printf '%s\n' "$vars0" "$vars1")

    printf '%s' "$raw" | grep -v "$match" > /dev/stderr

    printf \
      '%s' "$raw" |\
      grep "$match" |\
      sed "s/$prefix//g" |\
      tee /dev/stderr
  }

  eval $(get_vars)

  set -x
  bootstrap_main
  set +x
  root 'done'
}

function main() {
  configure

  local d8=8.8
  local d9=9.2
  local d0=$1

  bootstrap $(case $d0 in
    8) echo $d8 ;;
    9) echo $d9 ;;
    :) echo $d9 ;;
    *) echo $d0 ;;
  esac)
}

main $(a=$@; [ "$a" == "" ] && echo : || echo $1)
