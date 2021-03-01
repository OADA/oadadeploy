#! /bin/bash

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
SCRIPTNAME=$0

# If no OADA_HOME, set it to the absolute path of this script
if ! test -d OADA_HOME; then
  OADA_HOME="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
fi
cd "${OADA_HOME}"


#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# Utilities:
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

jq() { 
  docker run --rm -i -v "${PWD}:/code" oada/admin jq "$@" 
}
yq() { 
  docker run --rm -i -v "${PWD}:/code" oada/admin yq "$@" 
}
# yq doesn't merge anything if any of the files is empty, this is how yq says to test for empty file
ensure_nonempty_yml() {
  yq e --exit-status 'tag == "!!map" or tag== "!!seq"' $1 2>&1
}
# Use yq to do the same thing docker does w/ multiple yml files
yq_deep_merge() {
  local cmd res
  # Construct string for yq like "select(fi == 0) *d select(fi == 1)"
  # Need one entry for every file's index
  # The *d says what kind of merging happens, in this case a deep merge
  cmd="'"
  for ((i=0; i<$#; i++)); do
    res=$(ensure_nonempty_yml $1)
    if [ "$?" -ne 0 ]; then
      echo "ERROR: file $1 is empty or invalid yml.  It must at least contain one element (like version)." 1>&2
      echo "$res"
      exit 1
    fi
    if [ "$i" -gt 0 ]; then
      cmd="${cmd} *d"
    fi
    cmd="${cmd} select(fi == ${i})"
    shift
  done
  cmd="${cmd}'"
  # output result of merge to stdout
  eval "yq eval-all ${cmd} $@"
}

# Run docker-compose config on existing setup to confirm it all looks good to docker:
validate_compose() {
  local RES
  RES=$(docker-compose "$@" config 2>&1)
  if [ "$?" -ne 0 ]; then
    echo $RES;
    return 1;
  fi
  return 0;
}

# List all the docker-compose files that would be included in docker-compose.yml
compose_files() {
  echo "oada/docker-compose.yml"
  find ./services -name "docker-compose.yml"
}

# Rebuild docker-compose.yml from all the services and oada
refresh_compose() {
  local res
  yq_deep_merge $(compose_files) > new.docker-compose.yml
  res=$(validate_compose -f new.docker-compose.yml -f docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Newly merged docker-compose.yml would be invalid to docker, aborting.  Failed merge is in new.docker-compose.yml"
    echo "Manually fix and check w/ ${YELLOW}docker-compose -f new.docker-compose.yml -f docker-compose.override.yml config${NC}"
    echo "$res"
    return 1;
  else
    mv new.docker-compose.yml docker-compose.yml
    return 0;
  fi
}
merge_with_override() {
  local res
  # Merge into a temp file: note the 2>&1 before the > means stderr will go into this variable
  res=$(yq_deep_merge docker-compose.override.yml "$@" 2>&1 > new.docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Failed to merge $@ with docker-compose.override.yml: resulting file would be invalid yml.  Aborting.  Failed merge is in new.docker-compose.override.yml."
    echo $res
    return 1
  fi

  # Ensure tmp file is valid yml
  res=$(ensure_nonempty_yml new.docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Validtion of merge of $@ w/ docker-compose.override.yml failed: resulting file would be invalid yml.  Aborting.  Failed merge is in new.docker-compose.override.yml."
    echo $res
    return 1
  fi

  # Ensure primary docker env would still be valid:
  res=$(validate_compose -f docker-compose.yml -f new.docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Failed to merge $@ with docker-compose.override.yml: resulting overall docker setup invalid.  Aborting.  Failed merge is in new.docker-compose.override.yml."
    echo "Manually fix and check w/ ${YELLOW}docker-compose -f docker-compose.yml -f new.docker-compose.override.yml config${NC}"
    return 1
  fi

  # Replace old override w/ new one
  mv new.docker-compose.override.yml docker-compose.override.yml
}

# Remove a service's entry from yml file
remove_services_from_yml() {
  local COMPOSEFILE SERVICES cmd res
  COMPOSEFILE="$1"
  shift
  SERVICES="$@"

  # construct command like del(.services.admin) | del(.services.yarn)
  cmd="'"
  for ((i=0; i<${#SERVICES[@]}; i++)); do
    if [ "$i" -gt 0 ]; then
      cmd="${cmd} |"
    fi
    cmd="${cmd} del(.services.${SERVICES[$i]})"
  done
  cmd="${cmd}'"

  # Send it off to yml, store in tmp file in case we fail:
  eval "yq e ${cmd} ${COMPOSEFILE}" > new.${COMPOSEFILE}
  res=$(ensure_nonempty_yml new.${COMPOSEFILE})
  if [ "$?" != 0 ]; then
    echo "ERROR: failed to remove services $SERVICES from ${COMPOSEFILE}: resulting yml would be empty or invalid. Aborting"
    echo "Failed attempt is in new.${COMPOSEFILE}"
    return 1
  fi
  mv new.${COMPOSEFILE} ${COMPOSEFILE}
}


#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# admin 
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

admin() {
  CMD=$1
  shift
  case $CMD in
    # add|rm the dummy tokens/users from db
    devusers)
      case $2 in 
        add)
          echo -e "${YELLOW}arangodb__ensureDefaults=true docker-compose up -d startup${NC}"
          arangodb__ensureDefaults=true docker-compose up -d startup
        ;;
        rm)
          echo -e "${YELLOW}arangodb__ensureDefaults=false docker-compose up -d startup${NC}"
          arangodb__ensureDefaults=false docker-compose up -d startup
        ;;
        *) echo -e "USAGE: $SCRIPTNAME admin devusers [add|rm]" ;;
      esac
    ;;

    # extend token expiration
    extendToken)
      echo "${YELLOW}docker-compose run --rm auth extendToken $@${NC}"
      docker-compose run --rm auth extendToken $@
    ;;

    # add users
    useradd) 
      echo "${YELLOW}docker-compose run --rm user add $@${NC}"
      docker-compose run --rm user add $@
    ;;

    # just run bash in admin container
    bash)
      echo "${YELLOW}docker-compose run --rm admin bash $@${NC}"
      docker-compose run --rm admin bash
    ;;

    # run admin container w/ passthru commands, mapping . to /code
    *)
      echo "${YELLOW}docker run --rm -v .:/code admin $@${NC}"
      docker run --rm -v .:/code admin $@
    ;;
  esac
}



#-----------------------------------------------------------------------------
# migrate 
#-----------------------------------------------------------------------------

migrate() {
  local OLD OLDBASE NEWBASE NEWNAME VOLS
  # Check for help
  [[ $@ =~ -h|--help|help|\? ]] && usage migrate
  OLD=$1
  while [ ! -d "$OLD" ]; do
    read -p "${GREEN}Where is the installation you want to migrate from? " OLD
  done
  # Remove any trailing slashes
  OLD=${OLD%/}

  # Stop previous installation
  # If the old oada command is present, do that:
  if [ command -v oada &> /dev/null ]; then
    echo "${YELLOW}oada stop${NC}"
    oada stop
  elif [ ! "$(docker ps -q)" == "" ]; then
    # Otherwise, just stop everything in docker
    echo "Did not find oada command, stopping everything in docker for safety when moving volumes"
    echo "${YELLOW}docker stop \$(docker ps -q)${NC}"
    docker stop $(docker ps -q)
  fi


  # Copy any services-enabled
  if [ -d "$OLD/services-enabled" ]; then
    read -p "Copy services-enabled? [N|y] " YN
    if [[ "$YN" =~ y|Y|yes ]]; then
      echo "${YELLOW}cp -rf $OLD/services-enabled/* ./services/.${NC}"
      cp -rf $OLD/services-enabled/* ./services/.

      # Check for z_tokens: add it to docker-compose.override.yml if it exists
      if [ -f "./services/z_tokens/docker-compose.yml" ]; then
        echo "Found ${CYAN}z_tokens${NC}, adding it explicitly to docker-compose.override.yml and removing from ./services"
        merge_with_override services/z_tokens/docker-compose.yml \
        && rm -rf ./services/z_tokens
      fi

      # Every "old" service contained an entry for admin and possibly yarn containers.  Removing those entries will fix 90% of upgrade issues.
      for i in $(cd ./services && ls); do
        remove_services_from_yml $i/docker-compose.yml admin yarn || exit 1
      done

      # Refresh docker-compose.yml with the service's docker-compose.yml files
      refresh_compose
    fi
  fi

  # Copy any domains-enabled
  if [ -d "$OLD/domains-enabled" ]; then
    read -p "Copy domains-enabled? [N|y] " YN
    if [[ "$YN" =~ y|Y|yes ]]; then
      echo "${YELLOW}cp -rf "$OLD/domains-enabled/*" ./domains/.${NC}"
      cp -rf $OLD/domains-enabled/* ./domains/.
      for i in $(ls ./domains); do
        echo "    Enabling domain ${CYAN}$i${NC}"
        domain_enable $i
      done
    fi
  fi

  # Copy any docker volumes w/ prior folder name as prefix into current folder name
  read -p "Copy docker volumes?? [N|y] " YN
  if [[ "$YN" =~ y|Y|yes ]]; then
    OLDBASE=$(basename "$OLD")
    NEWBASE=$(basename "$OADA_HOME")
    VOLS=$(docker volume ls -qf name="${OLDBASE}")

    for v in $VOLS; do
      NEWNAME="${NEWBASE}${v#$OLDBASE}"
      echo "    Copying volume ${CYAN}$v${NC} to ${CYAN}$NEWNAME${NC}"
      docker volume create $NEWNAME &> /dev/null || echo "ERROR: FAILED TO CREATE VOLUME $NEWNAME"
      # from https://github.com/gdiepen/docker-convenience-scripts/blob/master/docker_clone_volume.sh
      docker run --rm \
           -v $v:/old \
           -v $NEWNAME:/new \
           alpine ash -c "cd /old; cp -av . /new" &> /dev/null
    done
  fi

  # Add all service docker-composes to 

  echo "Migration complete"
}



#-----------------------------------------------------------------------------
# fetch/upgrade
#-----------------------------------------------------------------------------

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



#-------------------------------------------------------------------------
# usage
#-------------------------------------------------------------------------

usage() {
  local CMD
  CMD=$1

  case $CMD in 

    migrate) echo -e "\n\
Migrate from an older Git-based installation to v3+ image-based installation
${GREEN}USAGE: $SCRIPTNAME migrate [path/to/old/oada-srvc-docker]

STOPS docker from old installation
Copies services-enabled
Copies domains-enabled
Migrates any docker volumes to new volume name for this installation
If you had z_tokens service, it adds that into docker-compose.override.yml
Refreshes docker-compose.yml and docker-compose.override.yml"

    ;;
    upgrade) echo -e "\n\
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

    ;;
    init) echo -e "\n\
Initialize current folder for an OADA deployment
${GREEN}USAGE: $SCRIPTNAME init${NC}

Creates support, oada, domains, and services folders.
Enables $SCRIPTNAME bash completion."

    ;;
    *)
      echo -e "\n\
Manage local oada installation and supporting services.

${GREEN}USAGE: $SCRIPTNAME [COMMAND] [ARGS...]${NC}
OADA Commands: 
   ${CYAN}init${NC}\t\tInitialize current directory w/ oada and supporting structure
   ${CYAN}upgrade${NC}\tUpgrade current oada to a different version
   ${CYAN}admin${NC}\tRun oada admin command, refer to admin help for specific commands
   ${CYAN}domain${NC}\tSetup or modify a domains
   ${CYAN}service${NC}\tInstall, upgrade, enable, or disable specific supporting services
   ${CYAN}devusers${NC}\tAdd/Remove default users and tokens: for dev only, this is insecure.

docker-compose commands supported as passthru w/ bash-completion (refer to docker-compose documentation):
   ${YELLOW}build, config, create, down, events, exec, help, images, kill, logs, pause,
   port, ps, pull, push, restart, rm, run, scale, start, stop, top, unpause, up${NC}

OADA_HOME env var sets which oada deployment used ${OADA_HOME}."

    ;;
  esac
  exit 1
}



#----------------------------------------------------------------------------
# init
#----------------------------------------------------------------------------

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
  local COMPOSE_VERSION
  [[ $@ =~ -h|--help|help|\? ]] && usage init
  # Create the necessary folder structure:
  mkdir -p domains services oada .oadadeploy

  # Setup and maintain a ./.oadadeploy/ folder to drive bash_completion and store other info
  # store OADA_HOME in bash-completion, default to current env
  echo "[ ! -z \${OADA_HOME} ] && OADA_HOME=\"${OADA_HOME}\"" > .oadadeploy/bash-completion
  docker run --rm oada/admin cat /support/bash-completion >> .oadadeploy/bash-completion
  ensure_bash_completion_in_bashrc

  # symlink at /usr/local/bin to run from anywhere
  LNPATH=/usr/local/bin/oadadeploy
  # Only ask the user if this script is not already the default:
  if [ "$(readlink $LNPATH)" != "$OADA_HOME/oadadeploy" ]; then
    read -p "${GREEN}Make this ${NC}oadadeploy${GREEN} script default on this machine?${NC} [Y|n] " YN
    if [[ "x$YN" =~ ^(x|xy|xY)$ ]]; then
      echo -e "\tSymlinking to /usr/local/bin/oadadeploy"
      [ -h $LNPATH ] && unlink $LNPATH
      ln -s "$OADA_HOME/oadadeploy" /usr/local/bin/oadadeploy || exit 1
    fi
  fi

  # If no docker-compose, pull one
  [ -f docker-compose.yml ] || upgrade || exit 1

  # If no overrides, go ahead and make one
  if [ ! -f docker-compose.override.yml ]; then
    # yq_deep_merge won't work if it's empty, so start it w/ a version
    COMPOSE_VERSION="3.9"
    if ensure_nonempty_yml docker-compose.yml; then
      COMPOSE_VERSION=$(yq e '.version' docker-compose.yml)
    elif ensure_nonempty_yml oada/docker-compose.yml; then
      COMPOSE_VERSION=$(yq e '.vesion' oada/docker-compose.yml)
    fi
    echo "version: \"${COMPOSE_VERSION}\"" > docker-compose.override.yml
  fi

  echo -e "${CYAN}Initialization complete.${NC}"
  echo -e "${YELLOW}Some things to do now:${NC}"
  echo -e "    source ${OADA_HOME}/.oadadeploy/bash-completion"
  echo -e "    oadadeploy migrate /path/to/old/git/version/of/oada"
  echo -e "    oadadeploy domain add <my.domain>"
  echo -e "    oadadeploy service install trellisfw/trellis-monitor"
  echo -e "    oadadeploy up"
}

array_has_no_flags() {
  for arg in $@; do
    [[ "$arg" =~ ^- ]] && return 1; # found a flag, return false
  done
  return 0; # did not find it, return true (bash true is  0)
}
compose() {
  local command=$1
  shift;
  DEFAULTFLAGS=""

  # If no flags passed, lets set some defaults:
  if array_has_no_flags $@; then
    case $command in

      # Default logs to -f --tail=200
      logs) 
        DEFAULTFLAGS = "-f --tail=200"
      ;;

      # Add default "-d" to up
      up)
        DEFAULTFLAGS = "-d"
      ;;
    esac
  fi
  echo -e "${YELLOW}docker-compose $command ${DEFAULTFLAGS} $@ ${NC}"
  docker-compose $command ${DEFAULTFLAGS} $@
}


#-----------------------------------------------------------------------------
# Main command sorting:
#-----------------------------------------------------------------------------

# verify we have curl, docker, docker-compose
require() {
  local ERRS
  ERRS=""
  for i in $@; do
    if ! command -v $i ] &> /dev/null; then
      ERRS="${ERRS}\nERROR: $SCRIPTNAME requires command $i"
    fi
  done
  if [ ! "x${ERRS}" == "x" ]; then 
    echo -e $ERRS
    exit
  fi
} 
require curl docker docker-compose

# usage exits this script when done
[ "$#" -lt 1 ] && usage

CMD=$1
shift
case $CMD in 
  # Exact list of docker-compose commands to pass thru
  build|config|create|down|events|exec|help|images|kill|logs|pause|port|ps|pull|push|restart|rm|run|scale|start|stop|top|unpause|up) 
    compose $CMD $@

  ;;
  admin) admin $@ ;;
  init) init $@ ;;
  upgrade) upgrade $@ ;;
  domain) domain $@ ;;
  service) service $@ ;;
  migrate) migrate $@ ;;
  help|--help|-h) usage $@ ;;
  *) usage $@
esac


