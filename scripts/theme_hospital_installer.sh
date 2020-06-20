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
GAME_BASE_DIR=${HOME}/.config/CorsixTH
INSTALLER_MD5="e4cba7cfddd5dd2d4baf4761bc86a8c8" #setup_theme_hospital_v3_\(28027\).exe
GAME_FILES=(data \
	levels \
	qdata \
	anims \
	sound)
REQUIRED_PACKAGES=(corsix-th)

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
    echo "This script has not been tested with this version of the Theme Hospital installer."
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
  echo "***                   Theme Hospital                     ***"
  echo "***                   - INSTALLER -                      ***"
  echo "************************************************************"
  echo
  echo "This script will install and configure Theme Hospital on your"
  echo "system to run with the CorsixTH game engine."
  echo
  echo "Checking installer..."
  check_installer ${installer} ${INSTALLER_MD5}

  echo "Checking for dependencies..."
  check_dependencies ${REQUIRED_PACKAGES[@]}

  echo
  echo "******   INSTALLING THEME HOSPITAL   ******"
  tmp_dir=$(mktemp -d -t gog_theme_hospital_XXXXXXXX)
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
  mkdir -p "${GAME_BASE_DIR}"

  for file in ${GAME_FILES[@]}
  do
    src="${game_source}/${file}"
    dst="${GAME_BASE_DIR}/"
    msg="   Moving ${src} to ${dst}..." 
    echo ${msg}
    if [ -d "${src}" ] ; then
      mv "${src}" "${dst}"
      echo -e "\e[1A\e[K${msg}DONE!"
    fi
  done

  msg="   Configuring Theme Hospital to use GOG.COM game files..."
  echo "${msg}"
  sed -i "s+/usr/share/games/theme-hospital+${GAME_BASE_DIR}+g" "${GAME_BASE_DIR}/config.txt"
  echo -e "\e[1A\e[K${msg}DONE!"

  echo "Cleaning up..."  
  clean_up ${tmp_dir}
  echo
  echo "************************************************************"
  echo "***                   Theme Hospital                     ***"
  echo "***             - INSTALLATION COMPLETE -                ***"
  echo "************************************************************"
  echo
  echo "Theme Hospital has been installed on this system.  To start" 
  echo "playing, click on the CorsixTH icon in the Chrome"
  echo "application launcher under the linux folder."
  echo

  exit 0
}

main $1
