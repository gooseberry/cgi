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
GAME_BASE_DIR=${HOME}/.quakespasm
TMP_DIR=${HOME}/tmp_quake_installer
INSTALLER_MD5="c8acba92fca95b8ba67111fa81730141" #setup_quake_the_offering_2.0.0.6.exe
GAME_FILES=(id1/pak0.pak \
  id1/pak1.pak \
  hipnotic/pak0.pak \
  rogue/pak0.pak)
REQUIRED_PACKAGES=(quakespasm \
  innoextract \
  bchunk \
  mesa-utils \
  vorbis-tools)

# Helper Functions

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
    if dpkg --get-selections | grep "^$package[[:space:]]*install$" >/dev/null ; then
      echo -e "\e[1A\e[K   ${package}...OK"
    else
      echo -e "\e[1A\e[K   ${package}...FAILED"
      error_msg+=" \n   ${package}"
      errors=1
    fi
  done

  if [ ${errors} ] ; then
    error_msg+="\nPlease install missing packages and try again."
    echo -e "${error_msg}"
    exit_error
  fi
}

install_files () {
  src=$1
  dst=$2
  files=$3

  for file in "${files[@]}"
  do
    if [ -f "${src}/${file}" ] ; then
      mv "${src}/${file}" "${dst}/${file}"
    fi
  done
}

convert_music () {

  bin_file=$1
  cue_file=$2
  dest_dir=$3

  bchunk -w "${bin_file}" "${cue_file}" "${dest_dir}/track"
  rm "${dest_dir}/track01.iso"

  cd "${dest_dir}"
  for track in $( ls *.wav );
  do
    oggenc -q 8 "${track}"
    rm "${track}"
  done
}

download () {
  filename=$1

  wget "${BASE_URL}/${filename}" -O "${ICONS_DIR}/${filename}"
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
DSKTP
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
  echo "of Eternity, to run with the open source engine, Quakespasm."
  echo
  echo "Checking installer..."
  check_installer ${installer} ${INSTALLER_MD5}
  echo "Checking for dependencies..."
  check_dependencies ${REQUIRED_PACKAGES[@]}

  mkdir -p "${TMP_DIR}"

  innoextract --lowercase -d "${TMP_DIR}" "${installer}"
  game_source="${TMP_DIR}/app"

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
	exec_string="quakespasm -game hipnotic"
	;;
      rogue)
        echo "Dissolution of Eternity"
	bin_file="${game_source}/gamed.gog"
	cue_file="${game_source}/gamed.cue"
	desktop="quake-doe"
	name="Quake DoE"
	exec_string="quakespasm -game rogue"
        ;;
      *)
        echo "Quake the Offering"
	game_files+=("pak1.pak")
	bin_file="${game_source}/game.gog"
	cue_file="${game_source}/game.cue"
	desktop="quake"
	name="Quake"
	exec_string="quakespasm +playdemo demo1"
	;;
    esac	
  
    install_files "${game_source}" "${game_dir}" "${game_files[@]}"
    convert_music "${bin_file}" "${cue_file}" "${game_dir}/music/"
    
    # This part is only required if the game does not create a desktop entry.
    download "${desktop}.png"
    generate_desktop_entry "${desktop}" "${name}" "${exec_string}"
  done

    # Clean up delete the temp folder
    rm -rf "${TMP_DIR}" 

    exit 0
}

main $1
