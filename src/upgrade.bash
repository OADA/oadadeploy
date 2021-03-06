usage_upgrade() {
  echo -e "\n\
Upgrade existing deployment to a different oada version.
${GREEN}USAGE: $SCRIPTNAME upgrade [-y] [ls|latest|<version>]${NC}
    Without parameters, it prompts for version, default latest
    ${CYAN}ls${NC}\t\tList available OADA versions in github
    ${CYAN}latest${NC}\tReplace oada/docker-compose.yml with latest github release
    ${CYAN}<version>${NC}\tReplace oada/docker-compose.yml with <version>

Examples: 
    ${YELLOW}$SCRIPTNAME upgrade${NC}
    ${YELLOW}$SCRIPTNAME upgrade ls${NC}
    ${YELLOW}$SCRIPTNAME upgrade latest${NC}
    ${YELLOW}$SCRIPTNAME upgrade v3.0.0${NC}"
}

# upgrade_core [-y] [-h|-r <repo>] <directory> [latest|ls|version]
# upgrade_core -h
# upgrade_core ./oada -> put oada/oada-srvc-docker assets into ./oada folder
# upgrade_core ./oada latest -> oada/oada-srvc-docker @ latest into ./oada folder
# upgrade_core -r trellisfw/trellis-monitor ./services/trellis-monitor ->  put repo 
upgrade_core() {
  local DIR VERSION REPO OLDPWD ACCEPT_DEFAULTS
  # Check for help
  [[ $@ =~ -h|--help|help|\? ]] && usage upgrade

  ACCEPT_DEFAULTS=0
  if [ "$1" == "-y" ]; then
    ACCEPT_DEFAULTS=1
    shift
  fi

  # Default to oada, otherwise it is a service to upgrade
  REPO="oada/oada-srvc-docker"
  if [ "$1" == "-r" ]; then
    REPO=$2
    shift
    shift
  fi
  # Get the folder name:
  DIR="$1"
  shift

  # Figure out version to pull:
  VERSION=""
  if [ $# -gt 0 ]; then
    VERSION="$1"
  fi
  # upgrade ls will print the versions and exit
  if [ "$VERSION" == "ls" ]; then
    echo "${YELLOW}Available OADA release versions in github:${NC}"
    fetch_github_versions $REPO
    exit 0
  fi

  # Otherwise, they passed a version or need to be asked for one:
  if [ "$ACCEPT_DEFAULTS" -eq 1 ]; then
    VERSION="latest"
  fi
  while [ "x$VERSION" == "x" ]; do
    read -p "${GREEN}What version of $REPO would you like to use (default latest, ls to see versions)? ${NC}[latest|ls|<version>] " VERSION
    if [ "x$VERSION" == "x" ]; then 
      VERSION="latest"
    elif [ "$VERSION" == "ls" ]; then
      VERSION=""
      echo -e "${YELLOW} Fetching list of $REPO versions${NC}"
      fetch_github_versions $REPO
    fi
  done

  # Get the actual docker-compose and save to oada/docker-compose.yml
  OLDPWD="${PWD}"
  cd "${DIR}"
  fetch_github ${REPO} ${VERSION}
  cd "${OLDPWD}"

  # Recreate primary docker-compose.yml
  refresh_compose
}

upgrade() {
  local DEFAULTS
  if [ "$1" == "-y" ]; then
    DEFAULTS="-y"
    shift
  fi
  upgrade_core ${DEFAULTS} ./oada $@
}


