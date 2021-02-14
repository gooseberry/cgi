#!/usr/bin/env bash
#
# Good Old Chromebook (https://gooseberry.github.io)

# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail

readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Install Script Variables
readonly ICONS_DIR=${HOME}/.local/share/icons
readonly DESKTOP_ENTRIES=${HOME}/.local/share/applications
readonly BASE_URL="https://gooseberry.github.io/assets/images/"

# Game Specific Variables
GAME_BASE_DIR=${HOME}/.local/share/openxcom
GAME_CONFIG_DIR=${HOME}/.config/openxcom
APPIMAGE_URL="https://knapsu.eu/download/"
APPIMAGE_FILENAME="OpenXcom_1.0_x86-64.AppImage"
INSTALLER_MD5="31b98618a8f33eadc05700dda3c7d97b" #setup_x-com_ufo_defense_1.2_(28046).exe
APPIMAGE_MD5="007dc6a31e28540432a07dd12020e269" # OpenXcom_1.0_x86-64.AppImage
GAME_DIRS=(geodata \
	geograph \
	maps \
	routes \
	sound \
	terrain \
	ufograph \
	ufointro \
	units)
REQUIRED_PACKAGES=(wget \
	innoextract)

check_installer () {
  installer=$1
  hash_value=$2
  msg="   checking MD5SUM for ${installer}..."

  echo "${msg}"

  if md5sum --status -c<<< "${hash_value} ${installer}" ; then
    echo -e "\e[1A\e[K${msg}OK!"
  else
    echo -e "\e[1A\e[K${msg}FAILED!"
    echo
    echo "This script has not been tested with this version of the X-COM UFO Defense installer."
    echo "The script will attempt to install this version, but may fail."
  fi
}

check_dependencies () {
  packages=$@
  error_msg="\nThe following packages are not installed:"
  errors=0

  for package in ${packages[@]}
  do
    echo "   ${package}..."
    if dpkg --get-selections | grep "^$package[[:space:]]*install$" >/dev/null ; then
      echo -e "\e[1A\e[K   ${package}...OK!"
    else
      echo -e "\e[1A\e[K   ${package}...FAILED!"
      error_msg+=" \n   ${package}"
      errors=1
    fi
  done

  if [ ${errors} -eq "0" ] ; then
    echo "All dependencies have been found."
  else
    error_msg+="\nPlease install missing packages and try again."
    echo -e "${error_msg}"
    exit_error
  fi
}

generate_desktop_entry () {
  icon=$1
  name=$2
  exec_string=$3

  cat >${DESKTOP_ENTRIES}/${icon}.desktop <<-DSKTP
  [Desktop Entry]
  Encoding=UTF-8
  Value=1.0
  Type=Application
  Name=${name}
  Icon=${ICONS_DIR}/${icon}.png
  Path=/usr/games
  Exec=${exec_string}
DSKTP
}

clean_up () {
  echo "   Deleting temporary directory ${tmp_dir}..."
  rm -rf ${tmp_dir}
  echo -e "\e[1A\e[K   Deleting temporary directory ${tmp_dir}...DONE!"

}

exit_error () {
  echo
  echo "******  INSTALLATION ABORTED  ******"
  echo
  exit 1
}

main () {

  installer=$1

  echo "************************************************************"
  echo "***                 X-COM UFO Defense                    ***"
  echo "***                   - INSTALLER -                      ***"
  echo "************************************************************"
  echo
  echo "This script will install and configure X-COM UFO Defense on"
  echo "your system."
  echo
  echo "Checking installer..."
  check_installer ${installer} ${INSTALLER_MD5}

  echo "Checking for dependencies..."
  check_dependencies ${REQUIRED_PACKAGES[@]}

  echo
  echo "******   INSTALLING X-COM UFO DEFENSE   ******"
  tmp_dir=$(mktemp -d -t gog_x-com_ufo_defense_XXXXXXXX)
  echo "Extracting ${installer} to ${tmp_dir}..."
  if innoextract --lowercase -s -p -d "${tmp_dir}" "${installer}" ;  then
    echo -e "\e[1A\e[KExtracting ${installer} to ${tmp_dir}...DONE!"
  else
    echo "Extraction failed.  Aborting Installation."
    clean_up ${tmp_dir}
    exit_error
  fi

  game_source="${tmp_dir}"

  echo "Copying game files..."
  for dir in "${GAME_DIRS[@]}"
  do
    dst="${GAME_BASE_DIR}/data/${dir}"
    mkdir -p ${dst}
    src="${game_source}/${dir}"
    msg="   Moving ${src} to ${dst}..." 
    echo ${msg}
    mv "${src}"/* "${dst}"
    echo -e "\e[1A\e[K${msg}DONE!"
  done

  echo "Cleaning up..."  
  clean_up ${tmp_dir}
  echo
  echo "************************************************************"
  echo "***                 X-COM UFO Defense                    ***"
  echo "***             - INSTALLATION COMPLETE -                ***"
  echo "************************************************************"
  echo
  echo "X-COM UFO Defense has been installed on this system.  To start" 
  echo "playing, click on the OpenXcom icon in the Chrome"
  echo "application launcher under the linux folder."
  echo

  exit 0
}

main $1
