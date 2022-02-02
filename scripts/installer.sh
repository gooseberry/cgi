#!/usr/bin/env bash
#
# Generic installer script to help user install games onto crostini

# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail

readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Script Specific Variables
ICONS_DIR=${HOME}/.local/share/icons
DESKTOP_ENTRIES=${HOME}/.local/share/applications
BASE_URL="https://gooseberry.github.io/assets/images/"
SUPPORTED_GAMES=(descent2 "Descent 2"\
  quake "Quake: The Offering"\
  quake2 "Quake II: Quad Damage"\
  theme_hospital "Theme Hospital"\
  xcom "X-Com: UFO Defense")
SELECTED_GAME=""

# Download URLS
INNO_URL="https://constexpr.org/innoextract/files/innoextract-1.9-linux.tar.xz"

select_game () {
  SELECTED_GAME=$(zenity --list \
    --title="Select Game to Install" \
    --column="Name" --column="Description" \
    "${SUPPORTED_GAMES[@]}")
}

download() {
  rand="$RANDOM `date`"
  pipe="/tmp/pipe.`echo '$rand' | md5sum | tr -d ' -'`"
  mkfifo $pipe
  wget -c $1 2>&1 | while read data;do
    if [ "`echo $data | grep '^Length:'`" ]; then
      total_size=`echo $data | grep "^Length:" | sed 's/.*\((.*)\).*/\1/' |  tr -d '()'`
    fi
    if [ "`echo $data | grep '[0-9]*%' `" ];then
      percent=`echo $data | grep -o "[0-9]*%" | tr -d '%'`
      current=`echo $data | grep "[0-9]*%" | sed 's/\([0-9BKMG.]\+\).*/\1/' `
      speed=`echo $data | grep "[0-9]*%" | sed 's/.*\(% [0-9BKMG.]\+\).*/\1/' | tr -d ' %'`
      remain=`echo $data | grep -o "[0-9A-Za-z]*$" `
      echo $percent
      echo "#Downloading $1\n$current of $total_size ($percent%)\nSpeed : $speed/Sec\nEstimated time : $remain"
    fi
  done > $pipe &
 
  wget_info=`ps ax |grep "wget.*$1" |awk '{print $1"|"$2}'`
  wget_pid=`echo $wget_info|cut -d'|' -f1 `
 
  zenity --progress --auto-close --text="Connecting to $1\n\n\n" --width="350" --title="Downloading"< $pipe
  if [ "`ps -A |grep "$wget_pid"`" ];then
    kill $wget_pid
  fi
  rm -f $pipe
}

install_innoextract () {
  # Verify if version 1.9 of innoextract is present and download it if required.
  mkdir -p $HOME/innoextract
  cd $HOME/innoextract


download_script () {
  download "https://github.com/gooseberry/cgi/raw/main/scripts/quake_install.sh"
}

main () {
  select_game
  download_script
}


main
