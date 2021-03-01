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



