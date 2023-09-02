#!/bin/bash
# CudaText: file_type="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail

dist=alma
distro=${dist}linux
DisTro=AlmaLinux
baseroot=BaseOS
os_packages=os/Packages

# release=9.2
release=8.8

arch=$(uname -m)

echo arch=$arch

sudo=sudo
rpms_dest=.rpms

pkg0="microdnf"
pkg1="dnf langpacks-en"


if [ "$release" == "9.2" ]; then
  rpm_gpg_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-$DisTro-$major
  major=9
  minor=1
  tag=el9

  _r0="
    $distro-gpg-keys-$release-$minor.$tag $distro-release-$release-$minor.$tag
    $distro-repos-$release-$minor.$tag glibc-common-2.34-60.$tag
    glibc-langpack-en-2.34-60.$tag libgcc-11.3.1-4.3.$tag.$dist glibc-2.34-60.$tag
    ncurses-libs-6.2-8.20210508.$tag filesystem-3.16-2.$tag bash-5.1.8-6.${tag}_${minor}"

  _r1="setup-2.13.7-9 basesystem-11-13 tzdata-2023c-$minor ncurses-base-6.2-8.20210508"

  _r2=""
fi

if [ "$release" == "8.8" ]; then
  rpm_gpg_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-$DisTro
  major=8
  minor=1
  tag=el8

  _r0="
    $distro-release-$release-$minor.$tag glibc-common-2.28-225.$tag
    glibc-langpack-en-2.28-225.$tag libgcc-8.5.0-18.$tag.$dist glibc-2.28-225.$tag
    ncurses-libs-6.1-9.20180224.$tag filesystem-3.8-6.$tag bash-4.4.20-4.${tag}_6
    libselinux-2.9-8.$tag pcre2-10.32-3.${tag}_6 libsepol-2.9-3.$tag
    libreport-filesystem-2.9.5-15.$tag.$dist.$minor"

  _r1="setup-2.12.2-9 basesystem-11-5 tzdata-2023c-$minor ncurses-base-6.1-9.20180224"

  _r2="dnf-data-4.7.0-16.${tag}_8"

fi


root=/mnt/bootstrap-$distro-$release-$arch
chroot="$sudo chroot "$root
achroot="$sudo arch-chroot "$root

base_packages=https://mirror.dal.nexril.net/$distro/$release/$baseroot/$arch/$os_packages

rpms=""

mkdir -pv $rpms_dest

function download_rpm () {
  fail=false
  pr1=$1
  pr2=$2
  rm -vf $pr2
  wget $base_packages/$pr1 -O$pr2 || fail=true
  if [ "$fail" == "true" ]; then
    rm -rf $pr2
    exit 1
  fi
}

function download_rpms () {
  _rpms=$1
  [ "$_rpms" == "" ] && return
  suffix=$2
  for _rpm0 in $_rpms; do
    _rpm=$_rpm0.$suffix
    rpm=$rpms_dest/$_rpm
    [ -s $rpm ] || download_rpm $_rpm $rpm
    rpms+=" $rpm"
  done
}

download_rpms "$_r0" $arch.rpm
download_rpms "$_r1" $tag.noarch.rpm
download_rpms "$_r2" $dist.noarch.rpm

function use_parent_resolv_conf() {
  $sudo rm -vf $root/etc/resolv.conf
  cat /etc/resolv.conf | $sudo dd of=$root/etc/resolv.conf
}

dnf0="$sudo dnf -y --setopt=install_weak_deps=False --installroot=$root"
dnf1="$achroot microdnf -y"
dnf2="$achroot dnf -y"
bash="$chroot bash -c"

function to_dnf_conf() {
  $bash "printf '$1\n' >> /etc/dnf/dnf.conf"
}

set -x
$sudo -v
$sudo rm -rf $root/*
$sudo mkdir -pv $root

$sudo rpmdb --root $root --initdb
$sudo rpm --root $root -ivh $rpms
$sudo systemd-machine-id-setup --root=$root

[ -f "$rpm_gpg_key" ] || $sudo cp -iv $root/$rpm_gpg_key $rpm_gpg_key

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
