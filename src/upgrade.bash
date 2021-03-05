usage_upgrade() {
  echo -e "\n\
Upgrade existing deployment to a different oada version.
${GREEN}USAGE: $SCRIPTNAME upgrade [ls|latest|<version>]${NC}
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

fetch_github() {
  local CURL VER REPO RELEASE
  CURL="curl -fsSL"
  REPO=$1
  VER=$2

  # If there are no %'s already, try to urlencode so +'s and other things are prepped for URL
  if [[ ! "$VER" =~ "%" ]]; then 
    # Need the surrounding quotes so jq will parse
    VER=$(echo "\"$VER\"" | jq -r '@uri')
  fi

  # Figure out URL for Github
  echo -e "${YELLOW}Fetching version ${CYAN}${VER}${YELLOW} of docker-compose.yml from github repo ${REPO}${NC}"
  case "$VER" in 
    latest) INFOURL="https://api.github.com/repos/${REPO}/releases/${VER}" ;;
    *)      INFOURL="https://api.github.com/repos/${REPO}/releases/tags/${VER}"
  esac

  # Get info for release (to find docker-compose.yml link)
  RELEASE=$($CURL ${INFOURL})
  if [ $? -ne 0 ]; then 
    echo -e "Failed to retrieve version ${VER} from github for $1."
    exit 1
  fi
  URL=$(jq -r '(.assets[] | select(.name == "docker-compose.yml") | .browser_download_url)' <<< $"$RELEASE" )
  if [ $? -ne 0 ]; then
    echo "Failed to interpret release info response from github, response was $RELEASE"
    exit 1
  fi

  # Pull the docker-compose and store in oada/docker-compose.yml
  $CURL $URL > oada/docker-compose.yml
  if [ $? -ne 0 ]; then
    echo -e "Failed to retrieve docker-compose at URL $URL"
    rm oada/docker-compose.yml
    exit 1
  fi
  
}

fetch_github_versions() {
  local CURL RELEASES
  CURL="curl -fsSL"
  RELEASES=$($CURL https://api.github.com/repos/$1/releases)
  if [ $? -ne 0 ]; then
    echo "Failed to retrieve releases list for repo $1"
    exit 1
  fi
  echo "$RELEASES" | jq -r '.[] | .tag_name'
  if [ $? -ne 0 ]; then
    echo "Failed to interpret github response for releases, response was $RELEASES"
    exit 1
  fi
}

fetch_oada() {
  fetch_github oada/oada-srvc-docker $1
}

fetch_oada_versions() {
  fetch_github_versions oada/oada-srvc-docker
}

upgrade() {
  # Check for help
  [[ $@ =~ -h|--help|help|\? ]] && usage upgrade

  OADA_VERSION=$1
  # oada upgrade ls will print the versions and exit
  if [ "$OADA_VERSION" == "ls" ]; then
    echo "${YELLOW}Available OADA release versions in github:${NC}"
    fetch_oada_versions
    exit 0
  fi

  # Otherwise, they passed a version or need to be asked for one:
  while [ "x$OADA_VERSION" == "x" ]; do
    read -p "${GREEN}What oada version would you like to use (default latest, ls to see versions)? ${NC}[latest|ls|<version>] " OADA_VERSION
    if [ "x$OADA_VERSION" == "x" ]; then 
      OADA_VERSION="latest"
    elif [ "$OADA_VERSION" == "ls" ]; then
      OADA_VERSION=""
      echo -e "${YELLOW} Fetching list of OADA versions${NC}"
      fetch_oada_versions
    fi
  done

  # Get the actual docker-compose and save to oada/docker-compose.yml
  fetch_oada ${OADA_VERSION}

  # Recreate primary docker-compose.yml
  refresh_compose
}




