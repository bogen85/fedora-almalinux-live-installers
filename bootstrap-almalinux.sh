#!/bin/bash
# CudaText: lexer_file="Bash script"; tab_size=2; tab_spaces=yes;

set -euo pipefail
export BASHOPTS SHELLOPTS

function common_config() {
  dist=alma
  distro=${dist}linux
  DisTro=AlmaLinux
  baseroot=BaseOS
  os_packages=os/Packages

  arch=$(uname -m)

  echo arch=$arch

  sudo=sudo
  rpms_dest=.rpms

  pkg0="microdnf"
  pkg1="dnf langpacks-en"
}

function main() {
  common_config
  release=$(case "$1" in
    8) echo 8.8 ;;
    9) echo 9.2 ;;
    :) echo 9.2 ;;
    *) echo $1 ;;
  esac)

  source bootstrap-almalinux-main.sh
}

main $(a=$@; [ "$a" == "" ] && echo : || echo $1)
