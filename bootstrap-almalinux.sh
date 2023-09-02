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

function bootstrap() {
  local release=$1
  source bootstrap-almalinux-main.sh
}

function main() {
  common_config

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
