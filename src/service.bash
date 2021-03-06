
usage_service() {
  echo -e "\n\
Install new service or upgrade an existing service.
${GREEN}USAGE: $SCRIPTNAME service [install|upgrade|refresh] [giturl|service_name]

    ${CYAN}install <gitrepo> ${NC}\t\tInstall a new service, gitrepo is a string like ${YELLOW}trellisfw/trellis-monitor${NC}
    ${CYAN}upgrade <servicename> [latest|ls|<version>]${NC}\tUpgrade <servicename>, or ls available releases.
    ${CYAN}refresh${NC}\tRe-create services/docker-compose.yml from services/*/docker-compose.oada.yml

Examples: 
    ${YELLOW}$SCRIPTNAME service install trellisfw/trellis-monitor${NC}
    ${YELLOW}$SCRIPTNAME service upgrade trellis-monitor${NS}
    ${YELLOW}$SCRIPTNAME service upgrade trellis-monitor latest${NC}
    ${YELLOW}$SCRIPTNAME service upgrade trellis-monitor ls${NC}
    ${YELLOW}$SCRIPTNAME service upgrade trellis-monitor v1.0${NC}
    ${YELLOW}$SCRIPTNAME service refresh${NC}"
}

# Run the domain-add within the admin container so it doesn't have to keep dropping into
# to run jq, node, oada-certs, etc.
service_install() {
  local SERVICE_NAME REPO OLDPWD VERSION
  REPO=$1
  shift
  
  # get rid of the org part of the repo name (before the /), that will be the folder name
  # Setup the service folder
  SERVICE_NAME=${REPO#*/}
  if [ ! -d "services/$SERVICE_NAME" ]; then
    mkdir -p services/$SERVICE_NAME services/$SERVICE_NAME/.oadadeploy
    echo "$REPO" > services/$SERVICE_NAME/.oadadeploy/repo
  fi

  # Now use the generic upgrade to upgrade this service
  upgrade_core -r ${REPO} ./services/$SERVICE_NAME $@
}

# Upgrade does same thing as install, just need to swap out service name w/ repo
service_upgrade() {
  local REPO SERVICE_NAME
  SERVICE_NAME=$1
  shift
  if [ -e "services/$SERVICE_NAME/.git" ]; then
    echo "${YELLOW}services/$SERVICE_NAME${NC} is a git repo, to upgrade you need to git pull in that folder."
    exit 1
  fi
  if [ ! -d "services/$SERVICE_NAME" ]; then
    echo "Cannot upgrade service ${YELLOW}$SERVICE_NAME${NC} because ${YELLOW}services/$SERVICE_NAME${NC} does not exist.  Install it first."
    exit 1
  fi
  if [ -f "services/$SERVICE_NAME/.oadadeploy/repo" ]; then
    REPO="$(cat services/$SERVICE_NAME/.oadadeploy/repo)"
  else
    echo "Unable to determine origin repo for service $SERVICE_NAME"
    read -p "${GREEN}What is the origin github repo (like trellisfw/trellis-monitor) for service${YELLOW} $SERVICE_NAME${GREEN}?${NC} " REPO
  fi
  service_install $REPO $@
}

service() {
  local CMD
  # Check for help
  [[ $@ =~ -h|--help|help|\? ]] && usage service
  CMD="$1"
  shift
  case "$CMD" in 
    install) 
      service_install $@
    ;;
    upgrade) 
      service_upgrade $@
    ;;
    refresh)
      refresh_services
    ;;
  esac
}




