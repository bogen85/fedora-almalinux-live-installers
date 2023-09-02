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

packages0="dnf"
packages1="langpacks-en"

if [ "$release" == "9.2" ]; then
	baseroot=BaseOS

  _rpms0="  $distro-gpg-keys-$release-$minor.$tag"
  _rpms0+=" $distro-release-$release-$minor.$tag"
  _rpms0+=" $distro-repos-$release-$minor.$tag"
  _rpms0+=" glibc-common-2.34-60.$tag"
  _rpms0+=" glibc-langpack-en-2.34-60.$tag"
  _rpms0+=" libgcc-11.3.1-4.3.$tag.$dist"
  _rpms0+=" glibc-2.34-60.$tag"
  _rpms0+=" ncurses-libs-6.2-8.20210508.$tag"
  _rpms0+=" bash-5.1.8-6.${tag}_${minor}"
  _rpms0+=" filesystem-3.16-2.$tag"

  _rpms1="  setup-2.13.7-9"
  _rpms1+=" basesystem-11-13"
  _rpms1+=" tzdata-2023c-$minor"
  _rpms1+=" ncurses-base-6.2-8.20210508"
fi

base_packages=https://mirror.dal.nexril.net/$distro/$release/$baseroot/$arch/os/Packages

rpm_gpg_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-$DisTro-$major
rpms=""

mkdir -pv $rpms_dest

function download_rpm () {
  rpm=$1
  rpm1=$rpms_dest/$rpm
  test -r $rpm1 || wget $base_packages/$rpm -O$rpm1
  rpms+=" $rpm1"
}

for _rpm in $_rpms0; do download_rpm $_rpm.$arch.rpm;        done
for _rpm in $_rpms1; do download_rpm $_rpm.$tag.noarch.rpm;  done

set -x
$sudo -v
$sudo rm -rf $root/*
$sudo mkdir -pv $root

$sudo rpmdb --root $root --initdb
$sudo rpm --root $root -ivh $rpms
$sudo systemd-machine-id-setup --root=$root

[ -f "$rpm_gpg_key" ] ||\
	$sudo cp -iv $root/$rpm_gpg_key $rpm_gpg_key

cat /etc/resolv.conf | $sudo dd of=$root/etc/resolv.conf
$sudo dnf -y --installroot=$root --refresh upgrade
$sudo dnf -y --installroot=$root install $packages0

$chroot cat /etc/os-release

$achroot bash -c "echo LANG=en_US.UTF-8 | tee /etc/locale.conf"
$achroot bash -c "echo LC_MESSAGES=C | tee -a /etc/locale.conf"
$achroot rpmdb --rebuilddb
$achroot dnf -y install $packages1

$achroot dnf -y --refresh upgrade
