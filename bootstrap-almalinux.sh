#!/bin/bash
# CudaText: file_type="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail

dist=alma
distro=${dist}linux
DisTro=AlmaLinux
release=9.2
major=9
minor=1
tag=el9

arch=$(uname -m)

echo arch=$arch

root=/mnt/bootstrap-$distro-$release-$arch

sudo=sudo
rpms_dest=.rpms

chroot="$sudo chroot "$root
achroot="$sudo arch-chroot "$root

pkg0="dnf"
pkg1="langpacks-en"

if [ "$release" == "9.2" ]; then
	baseroot=BaseOS
  os_packages=os/Packages

  _r0="
    $distro-gpg-keys-$release-$minor.$tag $distro-release-$release-$minor.$tag
    $distro-repos-$release-$minor.$tag glibc-common-2.34-60.$tag
    glibc-langpack-en-2.34-60.$tag libgcc-11.3.1-4.3.$tag.$dist glibc-2.34-60.$tag
    ncurses-libs-6.2-8.20210508.$tag filesystem-3.16-2.$tag bash-5.1.8-6.${tag}_${minor}"

  _r1="setup-2.13.7-9 basesystem-11-13 tzdata-2023c-$minor ncurses-base-6.2-8.20210508"
fi

base_packages=https://mirror.dal.nexril.net/$distro/$release/$baseroot/$arch/$os_packages

rpm_gpg_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-$DisTro-$major
rpms=""

mkdir -pv $rpms_dest

function download_rpms () {
  _rpms=$1
  suffix=$2
  for _rpm0 in $_rpms; do
    _rpm=$_rpm0.$suffix
    rpm=$rpms_dest/$_rpm
    [ -r $rpm ] || wget $base_packages/$_rpm -O$rpm
    rpms+=" $rpm"
  done
}

download_rpms "$_r0" $arch.rpm
download_rpms "$_r1" $tag.noarch.rpm

function use_parent_resolv_conf() {
  $sudo rm -vf $root/etc/resolv.conf
  cat /etc/resolv.conf | $sudo dd of=$root/etc/resolv.conf
}

dnf0="$sudo dnf -y --setopt=install_weak_deps=False --installroot=$root"
dnf1="$achroot dnf -y"
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

$chroot cat /etc/os-release
$chroot cat /etc/dnf/dnf.conf
