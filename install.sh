##########################################################################################
#
# Magisk Module Installer Script
#
##########################################################################################
##########################################################################################
#
# Instructions:
#
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure and implement callbacks in this file
# 4. If you need boot scripts, add them into common/post-fs-data.sh or common/service.sh
# 5. Add your additional or modified system properties into common/system.prop
#
##########################################################################################

##########################################################################################
# Config Flags
##########################################################################################

# Set to true if you do *NOT* want Magisk to mount
# any files for you. Most modules would NOT want
# to set this flag to true
SKIPMOUNT=true

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=false

# Set to true if you need late_start service script
LATESTARTSERVICE=false

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE="
"

##########################################################################################
#
# Function Callbacks
#
# The following functions will be called by the installation framework.
# You do not have the ability to modify update-binary, the only way you can customize
# installation is through implementing these functions.
#
# When running your callbacks, the installation framework will make sure the Magisk
# internal busybox path is *PREPENDED* to PATH, so all common commands shall exist.
# Also, it will make sure /data, /system, and /vendor is properly mounted.
#
##########################################################################################
##########################################################################################
#
# The installation framework will export some variables and functions.
# You should use these variables and functions for installation.
#
# ! DO NOT use any Magisk internal paths as those are NOT public API.
# ! DO NOT use other functions in util_functions.sh as they are NOT public API.
# ! Non public APIs are not guranteed to maintain compatibility between releases.
#
# Available variables:
#
# MAGISK_VER (string): the version string of current installed Magisk
# MAGISK_VER_CODE (int): the version code of current installed Magisk
# BOOTMODE (bool): true if the module is currently installing in Magisk Manager
# MODPATH (path): the path where your module files should be installed
# TMPDIR (path): a place where you can temporarily store files
# ZIPFILE (path): your module's installation zip
# ARCH (string): the architecture of the device. Value is either arm, arm64, x86, or x64
# IS64BIT (bool): true if $ARCH is either arm64 or x64
# API (int): the API level (Android version) of the device
#
# Availible functions:
#
# ui_print <msg>
#     print <msg> to console
#     Avoid using 'echo' as it will not display in custom recovery's console
#
# abort <msg>
#     print error message <msg> to console and terminate installation
#     Avoid using 'exit' as it will skip the termination cleanup steps
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#
##########################################################################################
##########################################################################################
# If you need boot scripts, DO NOT use general boot scripts (post-fs-data.d/service.d)
# ONLY use module scripts as it respects the module status (remove/disable) and is
# guaranteed to maintain the same behavior in future Magisk releases.
# Enable boot scripts by setting the flags in the config section above.
##########################################################################################

print() { grep_prop $1 $TMPDIR/module.prop; }

author=$(print author)
name=$(print name)
version=$(print version)
versionCode=$(print versionCode)

unset -f print

# Set what you want to display when installing your module

print_modname() {
  ui_print " "
  ui_print "$name $version"
  ui_print "版权所有(C) 2017-2019, $author"
  ui_print "License: GPLv3+"
  ui_print " "
}

# Copy/extract your module files into $MODPATH in on_install.

on_install() {
  # The following is the default implementation: extract $ZIPFILE/system to $MODPATH
  # Extend/change the logic to whatever you want
  #ui_print "- Extracting module files"
  #unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2

  set -euxo pipefail
  trap 'exxit $?' EXIT

  # remove obsolete mm
  rm /data/media/mm 2>/dev/null || :

  # extract module files
  ui_print "解压模块文件..."
  unzip -o "$ZIPFILE" -d $TMPDIR >&2
  cd $TMPDIR
  mv -f mm /data/media/0/
  mv License* README* $MODPATH/

  set +euxo pipefail  
  version_info
}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases

set_permissions() {
  # The following is the default rule, DO NOT remove
  set_perm_recursive $MODPATH 0 0 0755 0644

  # Here are some examples:
  # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
  # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0     0       0644

  # permissions for mm executable
  set_perm /data/media/0/mm  0  0  0700
}

# You can add more functions to assist your custom script code

exxit() {
  set +euxo pipefail
  [ $1 -ne 0 ] && abort
  exit 0
}


version_info() {
  local line=""
  local println=false

  # a note on untested Magisk versions
  if [ ${MAGISK_VER/.} -gt 181 ]; then
    ui_print " "
    ui_print "注意：你的Magisk版本并未经过$author测试！"
    ui_print "如果运行过程中发现问题，请访问下方链接报告"
  fi

  ui_print " "
  ui_print "最近一次的修改(概率不显示)"
  ui_print " "
  cat $MODPATH/README.md | while IFS= read -r line; do
    if $println; then
      line="$(echo "    $line")" && ui_print "$line"
    else
      echo "$line" | grep -q \($versionCode\) && println=true \
        && line="$(echo "    $line")" && ui_print "$line"
    fi
  done
  ui_print " "

  ui_print "相关链接："
  ui_print "向VR25捐赠:paypal.me/vr25xda/"
  ui_print "VR25 Facebook 个人主页:facebook.com/VR25-at-xda-developers-258150974794782/"
  ui_print "原始模块源代码:github.com/Magisk-Modules-Repo/mm/"
  ui_print "汉化版源代码:github.com/Sunshine018/mm-Translate"
  ui_print "VR25 Telegram 交流群组:t.me/vr25_xda/"
  ui_print "VR25 Telegram 个人主页:t.me/vr25xda/"
  ui_print "XDA 项目页面: forum.xda-developers.com/apps/magisk/module-tool-magisk-manager-recovery-mode-t3693165/"
  ui_print " "

  ui_print "How to use-如何使用？"
  if $BOOTMODE; then
    ui_print "在任意一个支持终端命令的Recovery中，输入sh /sdcard/mm 并按照提示进行下一步操作"
  else
    ln -sf /sdcard/mm /sbin*/
    ui_print "接下来，在Recovery终端中输入sh /sdcard/mm 并按照提示进行下一步操作"
    ui_print "从此以后，你无需重新安装，每次运行只需遵照上述方法即可"
  fi

  ui_print "MM本体存放于/sdcard目录下，理论上一次安装终身有效(实际上你也无法通过卸载方式完全删除MM)"
  ui_print "以后若无需使用，直接在该目录下删除mm并卸载模块即可"
  ui_print " "
}
