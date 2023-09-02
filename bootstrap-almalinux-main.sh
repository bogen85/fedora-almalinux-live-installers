# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

source bootstrap-conf/$distro-$release.conf

base_packages=https://mirror.dal.nexril.net/$distro/$release/$baseroot/$arch/$os_packages

rpms=""

mkdir -pv $rpms_dest

root_src=/mnt/bootstrap-$distro-$release-$arch
root=$root_src.mnt

$sudo -v

if [ -d "$root" ]; then
  $sudo rm -rf $root/*
  $sudo umount $root -v || true
  $sudo rm -rf $root
fi

$sudo mkdir -pv $root_src $root
$sudo mount -v -o bind $root_src $root

chroot="$sudo chroot "$root
achroot="$sudo arch-chroot "$root

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

mount | grep -F $root_src
