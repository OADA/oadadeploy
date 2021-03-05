usage_refresh() {
  echo -e "\n\
Refresh docker-compose.yml from oada, services, and domains.
${GREEN}USAGE: $SCRIPTNAME refresh${NC}"
}

# List all the docker-compose files that would be included in docker-compose.yml
compose_files() {
  local ret
  ret=""
  if [ -f oada/docker-compose.yml ]; then
    ret="${ret} oada/docker-compose.yml"
  fi
  if [ -f domains/docker-compose.yml ]; then
    ret="${ret} domains/docker-compose.yml"
  fi
  ret="${ret} $(find ./services -name "docker-compose.oada.yml")"
  echo -n $ret
}

refresh_domains() {
  local DOMAINS cmd VERSION first DOMAIN EXTRA_DOMAINS OVERRIDE
  echo "Refreshing ${YELLOW}domains/docker-compose.yml${NC}"
  DOMAINS=($(cd domains && $ls | sed '/docker-compose/d'))
  # Swag needs a single DOMAIN, and the rest go into EXTRA_DOMAINS
  if [ "${#DOMAINS[@]}" -eq 0 ]; then
    echo "No available domains to refresh"
    return 1
  fi
  DOMAIN="${DOMAINS[0]}"
  EXTRA_DOMAINS=""
  # Put the rest of the domains as comma-separated list if there are any
  if [ "${#DOMAINS[@]}" -gt 1 ]; then
    EXTRA_DOMAINS="$(join "," ${DOMAINS[@]:1})"
  fi

  # Get the docker-compose version from oada if we have it:
  if [ -f oada/docker-compose.yml ]; then
    VERSION=$(yq e '.version' oada/docker-compose.yml)
  else
    VERSION="3.9"
  fi

  # Construct the entire domains/docker-compose.yml from scratch
  cmd=".version=\"${VERSION}\""
  cmd="${cmd} | .services.proxy.environment +=  [ \"DOMAIN=${DOMAIN}\", \"EXTRA_DOMAINS=${EXTRA_DOMAINS}\" ]"
  cmd="${cmd} | .services.auth.volumes += ["
  first=1
  for i in ${DOMAINS[@]}; do
    if [ "$first" -ne 1 ]; then
      cmd="${cmd},"
    else
      first=0
    fi
    cmd="${cmd} \"./domains/${i}:/oada/services/auth/domains/${i}\""
  done
  cmd="${cmd} ]"

  # Create the file
  yq -n e "$cmd" > domains/new.docker-compose.yml
  if [ "$?" -ne 0 ]; then
    echo "Failed to create domains/new.docker-compose.yml.  Aborting."
    exit 1
  fi

  # Make sure it isn't empty
  res=$(ensure_nonempty_yml domains/new.docker-compose.yml 2>&1)
  if [ "$?" -ne 0 ]; then
    echo "Domain refresh resulted in empty or invalid yml.  Failed result saved in ${YELLOW}domains/new.docker-compose.yml${NC}."
    echo $res
    exit 1
  fi

  # If we have a main docker-compose.yml, check if new domains would be valid
  if [ -f docker-compose.yml ]; then
    OVERRIDE=""
    if [ -f docker-compose.override.yml ]; then
      OVERRIDE="-f docker-compose.override.yml"
    fi

  # If we have a main docker-compose.yml, check if new domains would be valid
    validate_compose -f docker-compose.yml $OVERRIDE -f domains/new.docker-compose.yml
    if [ "$?" -ne 0 ]; then
      echo "Resulting domains/docker-compose.yml would be invalid after refresh.  Failed attempt saved in ${YELLOW}domains/new.docker-compose.yml${NC}"
      exit 1
    fi
  fi

  # If we get here, everything seems good so move new.docker-compose.yml to where it belongs
  mv domains/new.docker-compose.yml domains/docker-compose.yml
  echo "Done refreshing ${YELLOW}domains/docker-compose.yml${NC}"

  # Finally, merge it into the main docker-compose
  refresh_compose 
}



# Rebuild docker-compose.yml from all the services and oada
refresh_compose() {
  local res OVERRIDE DOMAINS VERSION

  echo "Refreshing ${YELLOW}docker-compose.yml${NC} from $(compose_files)"

  # Merge together services
  res="$(yq_deep_merge $(compose_files) 2>&1 > new.docker-compose.yml)"
  if [ "$?" -ne 0 ]; then
    echo "Failed merge of $(compose_files)."
    echo $res
    return 1;
  fi

  # We should keep the version from oada/docker-compose.yml
  if [ -f oada/docker-compose.yml ]; then
    VERSION=$(yq e '.version' oada/docker-compose.yml)
    yq -i e ".version=\"${VERSION}\"" new.docker-compose.yml
    if [ "$?" -ne 0 ]; then
      echo "Unable to set version from oada/docker-compose.yml"
      exit 1
    fi
  fi

  OVERRIDE=""
  if [ -f docker-compose.override.yml ]; then
    OVERRIDE="-f docker-compose.override.yml"
  fi

  res="$(validate_compose -f new.docker-compose.yml ${OVERRIDE})"
  if [ "$?" -ne 0 ]; then
    echo "Newly merged docker-compose.yml would be invalid to docker, aborting.  Failed merge is in new.docker-compose.yml"
    echo "Manually fix and check w/ ${YELLOW}docker-compose -f new.docker-compose.yml -f docker-compose.override.yml config${NC}"
    echo "$res"
    return 1;
  else
    mv new.docker-compose.yml docker-compose.yml
    echo "Refresh of ${YELLOW}docker-compose.yml${NC} complete."
    return 0;
  fi
}



refresh() {

  refresh_domains
  # refresh_domains actually refreshes compose too, so only need to run that 

}

