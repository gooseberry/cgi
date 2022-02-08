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
GAME_BASE_DIR=${HOME}/.quake
INSTALLER_MD5="c8acba92fca95b8ba67111fa81730141" #setup_quake_the_offering_2.0.0.6.exe
GAME_FILES=(id1/pak0.pak \
  id1/pak1.pak \
  hipnotic/pak0.pak \
  rogue/pak0.pak)
REQUIRED_PACKAGES=(libopus0 \
  libmad0 \
  innoextract \
  bchunk \
  mesa-utils \
  vorbis-tools)
QSS_URL="https://triptohell.info/moodles/qss/"
QSS_FILE="quakespasm_spiked_linux64_dev.zip"
QSS_DIR="$HOME/qss"
QSS_EXEC="$QSS_DIR/quakespasm-spiked-linux64"


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
    echo "This script has not been tested with this version of the Quake installer."
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
    if dpkg --get-selections | grep "^$package.*[[:space:]]*install$" >/dev/null ; then
      echo -e "\e[1A\e[K   ${package}...INSTALLED!"
    else
      echo -e "\e[1A\e[K   ${package}...MISSING!"
      echo "    Installing ${package}"
      sudo apt-get install ${package} -y
      echo
      echo
    fi
  done

  # Create the Icon and Applications directory if they don't exists
  mkdir -p ${ICONS_DIR}
  mkdir -p ${DESKTOP_ENTRIES} 
}

convert_music () {
  bin_file=$1
  cue_file=$2
  dest_dir=$3

  msg="   Extracting music tracks from CD image..."
  echo "${msg}"
  if bchunk -w "${bin_file}" "${cue_file}" "${dest_dir}/track" >/dev/null ; then
    rm "${dest_dir}/track01.iso"
    echo -e "\e[1A\e[K${msg}DONE!"
  else
    echo -e "\e[1A\e[K${msg}FAILED!"
    echo "   Failed to extract the music track.  Installation will continue without"
    echo "   music files."
    return
  fi

  echo "   Converting RAW CD audio to Ogg Vorbis format"
  cd "${dest_dir}"
  for track in $( ls *.wav );
  do
    msg="      ${track}..."
    echo "${msg}"
    if oggenc -Q -q 8 "${track}" >/dev/null ; then
      rm "${track}"
      echo -e "\e[1A\e[K${msg}DONE!"
    else
      echo -e "\e[1A\e[K${msg}FAILED!"
      echo "      Failed to convert ${track}.  Installation will continue without this track."
    fi
  done
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
  echo "***                Quake: The Offering                   ***"
  echo "***                   - INSTALLER -                      ***"
  echo "************************************************************"
  echo
  echo "This script will install and configure Quake: The offering"
  echo "and the expansion packs, Scourge of Armagon and Dissolution"
  echo "of Eternity, to run with the open source engine, Quakespasm"
  echo "Spiked."
  echo
  echo "Checking installer..."
  check_installer ${installer} ${INSTALLER_MD5}
  
  echo "Checking for dependencies..."
  check_dependencies ${REQUIRED_PACKAGES[@]}


  echo
  echo "******   INSTALLING QUAKE   ******"

  msg="Downloading QuakeSpasm Spiked..."
  echo "${msg}"
  mkdir -p $QSS_DIR
  wget -q "$QSS_URL$QSS_FILE" -O "$QSS_DIR/$QSS_FILE"
  echo -e "\e[1A\e[K${msg}DONE!"

  msg="Extracting $QSS_FILE..."
  echo "${msg}"
  unzip -q "$QSS_DIR/$QSS_FILE" -d "$QSS_DIR"
  echo -e "\e[1A\e[K${msg}DONE!"

  tmp_dir=$(mktemp -d -t gog_quake_XXXXXXXX)
  echo "Extracting ${installer} to ${tmp_dir}..."
  if innoextract --lowercase -s -p -d "${tmp_dir}" "${installer}" ;  then
    echo -e "\e[1A\e[KExtracting ${installer} to ${tmp_dir}...DONE!"
  else
    echo "Extraction failed.  Aborting Installation."
    clean_up ${tmp_dir}
    exit_error
  fi

  game_source="${tmp_dir}/app"

  echo "Copying game files..."
  # Install each map pack as it's own game.
  map_packs=("id1" "hipnotic" "rogue")
  for map_pack in "${map_packs[@]}"
  do
    game_dir="${GAME_BASE_DIR}/${map_pack}"
    game_files=("pak0.pak")
    mkdir -p "${game_dir}/music"
   
    case "${map_pack}" in
      hipnotic)
        echo "Scourge of Armagedon"
        bin_file="${game_source}/gamea.gog"
	cue_file="${game_source}/gamea.cue"
	desktop="quake-soa"
	name="Quake SoA"
	exec_string="$QSS_EXEC -basedir $GAME_BASE_DIR -game hipnotic"
	;;
     rogue)
        echo "Dissolution of Eternity"
	bin_file="${game_source}/gamed.gog"
	cue_file="${game_source}/gamed.cue"
	desktop="quake-doe"
	name="Quake DoE"
	exec_string="$QSS_EXEC -basedir $GAME_BASE_DIR -game rogue"
        ;;
      *)
        echo "Quake the Offering"
	game_files+=("pak1.pak")
	bin_file="${game_source}/game.gog"
	cue_file="${game_source}/game.cue"
	desktop="quake"
	name="Quake"
	exec_string="$QSS_EXEC -basedir $GAME_BASE_DIR +playdemo demo1"
	;;
    esac	
  
    for file in "${game_files[@]}"
    do
      msg="   Moving ${game_source}/${map_pack}/${file} to ${game_dir}/${file}..."
      echo ${msg}
      if [ -f "${game_source}/${map_pack}/${file}" ] ; then
        mv "${game_source}/${map_pack}/${file}" "${game_dir}/${file}"
        echo -e "\e[1A\e[K${msg}DONE!"
      fi
    done

    echo "   Downloading desktop icon..."
    wget -q "${BASE_URL}/${desktop}.png" -O "${ICONS_DIR}/${desktop}.png"
    echo -e "\e[1A\e[K   Downloading desktop icon...DONE!"

    echo "   Generating desktop shortcut..."
    generate_desktop_entry "${desktop}" "${name}" "${exec_string}"
    echo -e "\e[1A\e[K   Generating desktop shortcut...DONE!"


    convert_music "${bin_file}" "${cue_file}" "${game_dir}/music/"
  done

  echo "Cleaning up..."
  clean_up ${tmp_dir}
  echo
  echo "************************************************************"
  echo "***                Quake: The Offering                   ***"
  echo "***             - INSTALLATION COMPLETE -                ***"
  echo "************************************************************"
  echo
  echo "Quake: The Offering, along with the two map packs, Scourge of"
  echo "Armagon, and Dissolution of Eternity, have been installed on"
  echo "this system.  To start playing, click on the respective"
  echo "Quake icon in the Chrome application launcher under the linux"
  echo "folder."
  echo
  exit 0
}

main $1
