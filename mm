#!/sbin/sh
# Magisk Manager for Recovery Mode (mm)
# Copyright (C) 2017-2019, VR25 @ xda-developers
# License: GPLv3+


main() {

tmpDir=/dev/_mm
tmpf=$tmpDir/tmpf
tmpf2=$tmpDir/tmpf2
mountPath=/_magisk
img=/data/adb/magisk.img
[ -f $img ] || img=/data/adb/modules

echo -e "\nMagisk Manager for Recovery Mode (mm-Translate) 2021.02.16
版权所有 (C) 2017-2019, VR25 @ xda-developers
按照 GPLv3+ 开源\n"

trap 'exxit $?' EXIT

if is_mounted /storage/emulated; then
  echo -e "它只能在Recovery环境下使用！\n"
  exit 1
fi

umask 022
set -euo pipefail

mount /data 2>/dev/null || :
mount /cache 2>/dev/null || :

if [ ! -d /data/adb/magisk ]; then
  echo -e "本机未安装Magisk或者安装的Magisk不受支持。\n"
  exit 1
fi

mkdir -p $tmpDir
mount -o remount,rw /
mkdir -p $mountPath

[ -f $img ] && e2fsck -fy $img 2>/dev/null 1>&2 || :
mount -o rw $img $mountPath
cd $mountPath
options
}


options() {

  local opt=""

  while :; do
    echo -n "##########################
l) 列出所有已安装 Magisk 模块
##########################
功能
  c) 启动 Magisk 核心模式
  m) 更改 自动挂载选项
  d) 禁用/启用 Magisk 模块
  r) 移除 Magisk 模块
##########################
q) 退出
##########################

?) "
    read opt

    echo
    case $opt in
      m) toggle_mnt;;
      d) toggle_disable;;
      l) echo -e "已安装模块\n"; ls_mods;;
      r) toggle_remove;;
      q) exit 0;;
      c) toggle_com;;
    esac
    break
  done

  echo -en "\n按下[ENTER]继续/输入q并[ENTER]退出"
  read opt
  [ -z "$opt" ] || exit 0
  echo
  options
}


is_mounted() { grep -q "$1" /proc/mounts; }

ls_mods() { ls -1 $mountPath | grep -v 'lost+found' || echo "<None>"; }


exxit() {
  set +euo pipefail
  cd /
  umount -f $mountPath
  rmdir $mountPath
  mount -o remount,ro /
  rm -rf $tmpDir
  [ ${1:-0} -eq 0 ] && { echo -e "\n再见，玩机愉快！\n"; exit 0; } || exit $1
} 2>/dev/null


toggle() {
  local input="" mod=""
  local file="$1" present="$2" absent="$3"
  for mod in $(ls_mods | grep -v \<None\> || :); do
    echo -n "$mod ["
    [ -f $mountPath/$mod/$file ] && echo "$present]" || echo "$absent]"
  done

  echo -en "\n如何使用：输入一个模块名的部分来禁用/启用/删除模块。"
  echo -en "\n例如，输入一个'.'来禁用/启用/删除所有模块，或者viper/xpo"
  read input
  echo

  for mod in $(ls_mods | grep -v \<None\> || :); do
    if echo $mod | grep -Eq "${input:-_noMatch_}"; then
      [ -f $mountPath/$mod/$file ] && { rm $mountPath/$mod/$file; echo "$mod [$absent]"; } \
        || { touch $mountPath/$mod/$file; echo "$mod [$present]"; }
    fi
  done
}


toggle_mnt() {
  echo -e "切换自动挂载成功。\n"
  [ -f $img ] && { toggle auto_mount ON OFF || :; } \
    || toggle skip_mount OFF ON
}


toggle_disable() {
  echo -e "模块已被启用/禁用\n"
  toggle disable OFF ON
}


toggle_remove() {
  echo -e "已标记删除。这一模块将在下次启动时被移除([X])\n"
  toggle remove X " "
}


toggle_com() {
  if [ -f /cache/.disable_magisk ] || [ -f /data/cache/.disable_magisk ]; then
    rm /data/cache/.disable_magisk /cache/.disable_magisk 2>/dev/null || :
    echo "(i) Magisk 核心模式[关]"
  else
    touch /data/cache/.disable_magisk /cache/.disable_magisk 2>/dev/null || :
    echo "(i) Magisk 核心模式[开]"
  fi
}


main
