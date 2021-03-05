
jq() { 
  docker run --rm -i -v "${PWD}:/code" oada/admin jq "$@" 
}

yq() {
  docker run --rm -i -v "${PWD}:/code" oada/admin yq "$@" 
}

join() {
  IFS="$1"
  shift
  echo "$*"
}

# yq doesn't merge anything if any of the files is empty, this is how yq says to test for empty file
ensure_nonempty_yml() {
  # If the file doesn't exist, same as empty (error)
  if [ ! -f "$1" ]; then
    return 1 
  fi
  yq e --exit-status 'tag == "!!map" or tag== "!!seq"' $1 2>&1
}

# Use yq to do the same thing docker does w/ multiple yml files
yq_deep_merge() {
  local res
  # Make sure none of the files are empty, b/c that will screw up yq
  for i in $@; do
    res=$(ensure_nonempty_yml $i)
    if [ "$?" -ne 0 ]; then
      echo "ERROR: file $i is empty or invalid yml.  It must at least contain one element (like version)." 1>&2
      echo "$res" 1>&2
      exit 1
    fi
  done
  # output result of merge to stdout
  yq ea '. as $item ireduce ({}; . *+ $item )' $@
}

# Run docker-compose config on existing setup to confirm it all looks good to docker:
validate_compose() {
  local RES
  RES="$(docker-compose "$@" config 2>&1 > /dev/null)"
  if [ "$?" -ne 0 ]; then
    echo "$RES";
    return 1;
  fi
  return 0;
}

merge_with_override() {
  local res skipvalidate
  if [ "$1" == "--skip-validate" ]; then
    skipvalidate=1
    shift;
  fi
  # Merge into a temp file: note the 2>&1 before the > means stderr will go into this variable
  res="$(yq_deep_merge docker-compose.override.yml "$@" 2>&1 > new.docker-compose.override.yml)"
  if [ "$?" -ne 0 ]; then
    echo "Failed to merge $@ with docker-compose.override.yml: resulting file would be invalid yml.  Aborting.  Failed merge is in new.docker-compose.override.yml."
    echo $res
    return 1
  fi

  # Ensure tmp file is valid yml
  res="$(ensure_nonempty_yml new.docker-compose.override.yml 2>&1)"
  if [ "$?" -ne 0 ]; then
    echo "Validtion of merge of $@ w/ docker-compose.override.yml failed: resulting file would be invalid yml.  Aborting.  Failed merge is in new.docker-compose.override.yml."
    echo $res
    return 1
  fi

  # Ensure primary docker env would still be valid:
  if  [ "$skipvalidate" -ne 1 ]; then
    res="$(validate_compose -f docker-compose.yml -f new.docker-compose.override.yml 2>&1)"
    if [ "$?" -ne 0 ]; then
      echo "Failed to merge $@ with docker-compose.override.yml: resulting overall docker setup invalid.  Aborting.  Failed merge is in new.docker-compose.override.yml."
      echo "Manually fix and check w/ ${YELLOW}docker-compose -f docker-compose.yml -f new.docker-compose.override.yml config${NC}"
      echo $res
      return 1
    fi
  fi

  # Replace old override w/ new one
  mv new.docker-compose.override.yml docker-compose.override.yml
}

# Remove a service's entry from yml file
remove_services_from_yml() {
  local i COMPOSEFILE SERVICES cmd res tmpcompose
  COMPOSEFILE="$1"
  shift
  SERVICES=( $@ )

  # construct command like del(.services.admin) | del(.services.yarn)
  cmd=""
  for ((i=0; i<${#SERVICES[@]}; i++)); do
    if [ "$i" -gt 0 ]; then
      cmd="${cmd} |"
    fi
    cmd="${cmd} del(.services.${SERVICES[$i]})"
  done

  # Send it off to yml, store in tmp file in case we fail:
  tmpcompose="$(dirname $COMPOSEFILE)/new.$(basename $COMPOSEFILE)"
  yq e "${cmd}" ${COMPOSEFILE} > ${tmpcompose}
  if [ "$?" != 0 ]; then
    echo "ERROR: Failed to execute service deletion in yq for $COMPOSEFILE."
    echo "${YELLOW}yq e ${cmd} ${COMPOSEFILE}${NC}"
    echo "$res"
    return 1
  fi

  res="$(ensure_nonempty_yml ${tmpcompose})"
  if [ "$?" != 0 ]; then
    echo "ERROR: failed to remove services $SERVICES from ${COMPOSEFILE}: resulting yml would be empty or invalid. Aborting"
    echo "Failed attempt is in ${tmpcompose}"
    return 1
  fi
  mv "${tmpcompose}" ${COMPOSEFILE}
}



