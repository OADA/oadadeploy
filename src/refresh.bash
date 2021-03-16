usage_refresh() {
  echo -e "\n\
Refresh docker-compose.yml from oada, services, and domains.
${GREEN}USAGE: $SCRIPTNAME refresh${NC}"
}

# List all the docker-compose files that would be included in docker-compose.yml
services_compose_files() {
  find ./services -name "docker-compose.oada.yml"
}

# If you set your DOMAIN env var, you can force your DOMAIN to be a particular one of your domains
refresh_domains() {
  local DOMAINS cmd VERSION first DOMAIN EXTRA_DOMAINS OVERRIDE res

  # If we have a main docker-compose.yml, check if it is valid first.  If not, abort b/c we won't be able to validate
  # the final compose setup
  if [ -f docker-compose.yml ]; then
    # If we have a main docker-compose.yml, check if new domains would be valid
    # Do not check override b/c it could be invalid, but domains still be fine
    validate_compose -f docker-compose.yml
    if [ "$?" -ne 0 ]; then
      echo "Your current docker-compose setup is invalid.  Aborting.  Fix it, validate with ${CYAN}docker-compose -f docker-compose.yml config${NC} and try again."
      exit 1
    fi
  fi

  echo "Refreshing ${YELLOW}domains/docker-compose.yml${NC}"
  DOMAINS=($(cd domains && $ls | sed '/docker-compose/d'))
  # Swag needs a single DOMAIN, and the rest go into EXTRA_DOMAINS
  if [ "${#DOMAINS[@]}" -eq 0 ]; then
    echo "No available domains to refresh"
    return 1
  fi

  # If we have a domain from ENV, remove it from list of domains
  if [ ! -z "$DOMAIN" ]; then
    echo "Using primary domain ${YELLOW}$DOMAIN${NC} from environment"
  # Otherwise, check if we has a saved primary domain:
  elif [ -f ".oadadeploy/primarydomain" ]; then
    DOMAIN="$(cat .oadadeploy/primarydomain)"
    echo "Using primary domain ${YELLOW}${DOMAIN}${NC} from saved .oadadeploy/primarydomain"
  else
    echo "No saved primary domain found.  Defaulting to ${DOMAINS[0]}."
    echo "${DOMAINS[0]}" > .oadadeploy/primarydomain
    DOMAIN="${DOMAINS[0]}"
  fi

    
  # comma-separated list of the rest of the domains, excluding primary
  EXTRA_DOMAINS=$(join "," ${DOMAINS[@]#$DOMAIN})
  # Write the DOMAIN env to .env to keep docker-compose happy
  if [ ! -f ".env" ]; then
    echo "" > .env
  fi
  res="$(sed "/DOMAIN=*/d" .env)"
  echo "DOMAIN=${DOMAIN}" > .env
  echo -n "$res" >> .env

  # Get the docker-compose version from oada if we have it:
  if [ -f oada/docker-compose.yml ]; then
    VERSION=$(yq e '.version' oada/docker-compose.yml)
  else
    VERSION="3.9"
  fi

  # Construct the entire domains/docker-compose.yml from scratch
  cmd=".version=\"${VERSION}\""
  cmd="${cmd} | .services.proxy.environment +=  [ \"URL=${DOMAIN}\", \"EXTRA_DOMAINS=${EXTRA_DOMAINS}\", \"SUBDOMAINS=\" ]"
  # If primary domain has an SSL cert in domains/<domain>/cert, mount it into proxy
  if [ -d "domains/${DOMAIN}/cert" ]; then
    echo "Primary domain has self-signed SSL cert at ${YELLOW}domains/${DOMAIN}/cert${NC}.  Mounting into proxy as main SSL cert."
    cmd="${cmd} | .services.proxy.volumes += [ \"./domains/${DOMAIN}/cert:/config/keys/letsencrypt:ro\" ]"
  fi
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
    # If we have a main docker-compose.yml, check if new domains would be valid
    validate_compose -f docker-compose.yml -f domains/new.docker-compose.yml
    if [ "$?" -ne 0 ]; then
      echo "Resulting ${YELLOW}domains/docker-compose.yml${NC} would be invalid after refresh.  Failed attempt saved in ${YELLOW}domains/new.docker-compose.yml${NC}"
      echo "You can test with ${CYAN}docker-compose -f docker-compose.yml -f domains/new.docker-compose.yml${NC}"
      exit 1
    fi
  fi

  # If we get here, everything seems good so move new.docker-compose.yml to where it belongs
  mv domains/new.docker-compose.yml domains/docker-compose.yml
  echo "Done refreshing ${YELLOW}domains/docker-compose.yml${NC}"

  refresh_compose
}


refresh_services() {

  echo "Refreshing ${YELLOW}services/docker-compose.yml${NC} from ${YELLOW}$(services_compose_files)${NC}"
  # Merge together services, have to use yq b/c resuling file is not a fully valid docker-compose
  res="$(yq_deep_merge $(services_compose_files) 2>&1 > services/new.docker-compose.yml)"
  if [ "$?" -ne 0 ]; then
    echo "Failed merge of ${YELLOW}$(services_compose_files)${NC}."
    echo $res
    return 1;
  fi
  mv services/new.docker-compose.yml services/docker-compose.yml

  refresh_compose
}



# Rebuild docker-compose.yml from all the services and oada
# --only will NOT refresh_domains and services first
refresh_compose() {
  local res DOMAINS SERVICES

  echo "Refreshing ${YELLOW}docker-compose.yml${NC} from ${YELLOW}oada/docker-compose.yml services/docker-compose.yml domains/docker-compose.yml${NC}"
  if [ ! -f oada/docker-compose.yml ]; then
    echo "You do not have oada installed in ${YELLOW}oada/docker-compose.yml${NC}. Aborting."
    exit 1
  fi

  [ -f "domains/docker-compose.yml" ] && DOMAINS="-f domains/docker-compose.yml"
  [ -f "services/docker-compose.yml" ] && SERVICES="-f services/docker-compose.yml"
  # Now combine the services-only merge w/ the oada/docker-compose.yml
  docker-compose --project-directory . -f oada/docker-compose.yml ${DOMAINS} ${SERVICES} config > new.docker-compose.yml
  if [ "$?" -ne 0 ]; then
    echo "Merging of files failed.  Result saved in ${YELLOW}new.docker-compose.yml${NC}."
    echo "${YELLOW}docker-compose --project-directory . -f oada/docker-compose.yml ${DOMAINS} ${SERVICES} config > new.docker-compose.yml${NC}"
  fi
  # We should keep the version from oada/docker-compose.yml
  VERSION=$(yq e '.version' oada/docker-compose.yml)
  yq -i e ".version=\"${VERSION}\"" new.docker-compose.yml
  if [ "$?" -ne 0 ]; then
    echo "Unable to set version from ${YELLOW}oada/docker-compose.yml${NC}"
    exit 1
  fi

  res="$(validate_compose -f new.docker-compose.yml)"
  if [ "$?" -ne 0 ]; then
    echo "Newly merged docker-compose.yml would be invalid to docker, aborting.  Failed merge is in new.docker-compose.yml"
    echo "Manually fix and check w/ ${CYAN}docker-compose -f new.docker-compose.yml config${NC}"
    echo "$res"
    return 1;
  fi
  mv new.docker-compose.yml docker-compose.yml
  echo "Refresh of ${YELLOW}docker-compose.yml${NC} complete."

  if [ -f docker-compose.override.yml ]; then
    res="$(validate_compose )"
    if [ "$?" -ne 0 ]; then
      echo "WARNING: the new ${YELLOW}docker-compose.yml${NC} is valid, but your ${YELLOW}docker-compose.overrides.yml${NC} makes it invalid."
      echo "$res"
      echo "Fix your overrides and check with ${CYAN}docker-compose config${NC}"
      return 1;
    fi
  fi
  
}


refresh() {
  refresh_compose
}

