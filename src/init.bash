usage_init() {
  echo -e "\n\
Initialize current folder for an OADA deployment
${GREEN}USAGE: $SCRIPTNAME init${NC}

Creates support, oada, domains, and services folders.
Enables $SCRIPTNAME bash completion."
}

ensure_bash_completion_in_bashrc() {
  # set OADA_HOME in bashrc
  # line after that just loads bash-completion from OADA_HOME/bash_completion
  if grep -q "OADA_HOME" ~/.bashrc; then
    # Replace OADA_HOME line w/ new OADA_HOME
    cat ~/.bashrc | sed "s:^OADA_HOME.*$:OADA_HOME=\"${OADA_HOME}\":" > /tmp/bashrc \
    && mv /tmp/bashrc ~/.bashrc
  else
    # Add both OADA_HOME and bash-completion lines to bashrc
    echo "OADA_HOME=\"${OADA_HOME}\"" >> ~/.bashrc
    echo '[[ -r ${OADA_HOME}/.oadadeploy/bash-completion ]] && . ${OADA_HOME}/.oadadeploy/bash-completion' >> ~/.bashrc
  fi
}

init() {
  local COMPOSE_VERSION ACCEPT_DEFAULTS ARGS ME
  [[ $@ =~ -h|--help|help|\? ]] && usage init

  ACCEPT_DEFAULTS=0
  if [ "$1" == "-y" ]; then
    ACCEPT_DEFAULTS=1
  fi

  # Create the necessary folder structure:
  mkdir -p domains services oada .oadadeploy support

  # Setup and maintain a ./.oadadeploy/ folder to drive bash_completion and store other info
  # store OADA_HOME in bash-completion, default to current env
  echo "[ ! -z \${OADA_HOME} ] && OADA_HOME=\"${OADA_HOME}\"" > .oadadeploy/bash-completion
  docker run --rm oada/admin cat /support/bash-completion >> .oadadeploy/bash-completion
  ensure_bash_completion_in_bashrc

  # symlink at /usr/local/bin to run from anywhere
  LNPATH=/usr/local/bin/oadadeploy
  # Only ask the user if this script is not already the default:
  if [ "$(readlink_crossplatform $LNPATH)" != "$OADA_HOME/oadadeploy" ]; then
    if [ "$ACCEPT_DEFAULTS" -ne 1 ]; then 
      read -p "${GREEN}Make this ${NC}oadadeploy${GREEN} script default on this machine?${NC} [Y|n] " YN
    else
      YN="y"
    fi
    if [[ "x$YN" =~ ^(x|xy|xY)$ ]]; then
      echo -e "\tSymlinking to /usr/local/bin/oadadeploy, THIS RUNS AS SUDO"
      [ -h $LNPATH ] && unlink $LNPATH
      sudo ln -s "$OADA_HOME/oadadeploy" /usr/local/bin/oadadeploy || exit 1
      ME=$(whoami)
      sudo chown "$ME" /usr/local/bin/oadadeploy
    fi
  fi

  # If no overrides, go ahead and make one
  if [ ! -f docker-compose.override.yml ]; then
    # yq_deep_merge won't work if it's empty, so start it w/ a version
    COMPOSE_VERSION="3.9"
    if ensure_nonempty_yml docker-compose.yml; then
      COMPOSE_VERSION=$(yq e '.version' docker-compose.yml)
    elif ensure_nonempty_yml oada/docker-compose.yml; then
      COMPOSE_VERSION=$(yq e '.version' oada/docker-compose.yml)
    fi
    echo "Initializing ${CYAN}docker-compose.override.yml${NC} with version ${COMPOSE_VERSION}"
    echo "version: \"${COMPOSE_VERSION}\"" > docker-compose.override.yml
  fi

  # If no docker-compose, pull one
  ARGS=""
  if [ "$ACCEPT_DEFAULTS" -eq 1 ]; then 
    ARGS="-y"
  fi

  [ -f docker-compose.yml ] || upgrade ${ARGS} || exit 1

  echo -e "${CYAN}Initialization complete.${NC}"
  echo -e "${YELLOW}Some things to do now:${NC}"
  echo -e "    source ${OADA_HOME}/.oadadeploy/bash-completion"
  echo -e "    oadadeploy migrate /path/to/old/git/version/of/oada"
  echo -e "    oadadeploy domain add <my.domain>"
  echo -e "    oadadeploy service install trellisfw/trellis-monitor"
  echo -e "    oadadeploy up"
  echo -e "${YELLOW}IMPORTANT:${NC}"
  echo -e "    You need add at least one domain. "
  echo -e "    If you have none then ${CYAN}oadadeploy domain add -y localhost${NC}"
}

