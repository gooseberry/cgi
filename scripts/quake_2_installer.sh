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
GAME_BASE_DIR=${HOME}/.yq2
INSTALLER_MD5="9bdc4b3a0fd426d1ccb2a55a46c4bf4a"  #setup_quake2_quad_damage_2.0.0.3.exe
MAP_PACKS=(baseq2 \
  xatrix \
  rogue) 
REQUIRED_PACKAGES=(quake2 \
  innoextract \
  mesa-utils) 

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
    echo "This script has not been tested with this version of the Quake II installer."
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

  # Create the Icon and Applications directory if they don't exists
  mkdir -p ${ICONS_DIR}
  mkdir -p ${DESKTOP_ENTRIES} 
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
  tmp_dir=$1

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
  echo "***               Quake II: Quad Damage                  ***"
  echo "***                   - INSTALLER -                      ***"
  echo "************************************************************"
  echo
  echo "This script will install and configure Quake II: The Quad "
  echo "Damage and the expansion packs, The Reckoning and Ground"
  echo "Zero, to run with the open source engine, Yamagi."
  echo
  echo "Checking installer..."
  check_installer ${installer} ${INSTALLER_MD5}
  
  echo "Checking for dependencies..."
  check_dependencies ${REQUIRED_PACKAGES[@]}

  echo
  echo "******   INSTALLING QUAKE II   ******"
  tmp_dir=$(mktemp -d -t gog_quake_XXXXXXXX)
  echo "Extracting ${installer} to ${tmp_dir}..."
  # not using lowercase tag because yagami looks for music in mixed case.
  if innoextract -s -p -d "${tmp_dir}" "${installer}" ;  then
    echo -e "\e[1A\e[KExtracting ${installer} to ${tmp_dir}...DONE!"
  else
    echo "Extraction failed.  Aborting Installation."
    clean_up ${tmp_dir}
    exit_error
  fi

  game_source="${tmp_dir}/app"

  echo "Copying game files...\n"
  mkdir -p "${GAME_BASE_DIR}"
  for map_pack in "${MAP_PACKS[@]}"
  do
   
    case "${map_pack}" in
      baseq2)
        echo "Quake II"
	desktop="quake2"
	name="Quake II"
	exec_string="/usr/lib/quake2/quake2-engine"
	;;
     xatrix)
        echo "The Reckoning"
	desktop="quake2-the-reckoning"
	name="Quake II: The Reckoning"
	exec_string="/usr/lib/quake2/quake2-engine +set game xatrix"
        ;;
      rogue)
        echo "Ground Zero"
	desktop="quake2-ground-zero"
	name="Quake II: Ground Zero"
	exec_string="/usr/lib/quake2/quake2-engine +set game rogue"
	;;
    esac	
    src="${game_source}/${map_pack}"
    dst="${GAME_BASE_DIR}/${map_pack}"
    mkdir -p "${dst}"

    msg="   Moving ${src} to ${dst}..."
    echo "${msg}"
    mv "${src}"/* "${dst}"
    echo -e "\e[1A\e[K${msg}DONE!"
  

    echo "   Downloading desktop icon..."
    wget -q "${BASE_URL}/${desktop}.png" -O "${ICONS_DIR}/${desktop}.png"
    echo -e "\e[1A\e[K   Downloading desktop icon...DONE!"

    echo "   Generating desktop shortcut..."
    generate_desktop_entry "${desktop}" "${name}" "${exec_string}"
    echo -e "\e[1A\e[K   Generating desktop shortcut...DONE!"

  done
  echo "Copying original game music..."
  src="${game_source}/music"
  dst="${GAME_BASE_DIR}/music"
  mkdir -p "${dst}"

  msg="   Moving ${src} to ${dst}..."
  echo "${msg}"
  mv "${src}"/* "${dst}"
  echo -e "\e[1A\e[K${msg}DONE!"
   


  echo "Cleaning up..."
  clean_up ${tmp_dir}
  echo
  echo "************************************************************"
  echo "***               Quake II: Quad Damage                  ***"
  echo "***             - INSTALLATION COMPLETE -                ***"
  echo "************************************************************"
  echo
  echo "Quake II: Quad Damage, along with the two map packs, The"
  echo "Reckoning, and Ground Zero, have been installed on"
  echo "this system.  To start playing, click on the respective"
  echo "Quake II icon in the Chrome application launcher under the linux"
  echo "folder."
  echo
  exit 0
}

main $1
