usage_migrate() {
  echo -e "\n\
Migrate from an older Git-based installation to v3+ image-based installation
${GREEN}USAGE: $SCRIPTNAME migrate [path/to/old/oada-srvc-docker]

STOPS docker from old installation
Copies services-enabled
Copies domains-enabled
Migrates any docker volumes to new volume name for this installation
If you had z_tokens service, it adds that into docker-compose.override.yml
Refreshes docker-compose.yml and docker-compose.override.yml"
}

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
    read -p "${GREEN}Copy services-enabled? [N|y]${NC} " YN
    if [[ "$YN" =~ y|Y|yes ]]; then
      echo "${YELLOW}cp -rf $OLD/services-enabled/* ./services/.${NC}"
      cp -rf $OLD/services-enabled/* ./services/.

      # Check for z_tokens: add it to docker-compose.override.yml if it exists
      if [ -f "./services/z_tokens/docker-compose.yml" ]; then
        echo "Found ${CYAN}z_tokens${NC}, adding it explicitly to docker-compose.override.yml and removing from ./services"
        merge_with_override --skip-validate services/z_tokens/docker-compose.yml || exit 1
        rm -rf ./services/z_tokens
        echo "z_tokens merged successfully"
      fi

      # Now do per-service fixups
      for i in $(cd ./services && $ls); do
        echo "Doing initial git pull in services/$i"
        # Do a git pull in case this service has already been updated to oada v3 model
        (cd ./services/$i && git pull && cd ..) || (echo "Failed to git pull in service $i" && exit 1)

        # If this service has a new docker-compose.oada.yml, do not auto-fix anything in it.
        # If it does not, assume that it needs to be auto-fixed
        if [ ! -f ./services/$i/docker-compose.oada.yml ]; then
          # Copy the base docker-compose to oada-specific version
          cp services/$i/docker-compose.yml services/$i/docker-compose.oada.yml
          # Every "old" service contained an entry for admin and possibly yarn containers.  Removing those entries will fix 90% of upgrade issues.
          echo "Cleaning any admin and yarn entries from services/$i/docker-compose.oada.yml"
          remove_services_from_yml services/$i/docker-compose.oada.yml admin yarn || exit 1
  
          # All the "old" services used services-available/<name>, change to services/<name>
          echo "Replacing services-available with services in services/$i/docker-compose.oada.yml"
          REPLACED="$(sed 's/services-available/services/g' services/$i/docker-compose.oada.yml)"
          echo "$REPLACED" > services/$i/docker-compose.oada.yml
        fi
      done

    fi
  fi

  # Copy any domains-enabled
  if [ -d "$OLD/domains-enabled" ]; then
    read -p "${GREEN}Copy domains-enabled? [N|y] ${NC}" YN
    if [[ "$YN" =~ y|Y|yes ]]; then
      echo "${YELLOW}cp -rf "$OLD/domains-enabled/*" ./domains/.${NC}"
      cp -rf $OLD/domains-enabled/* ./domains/.
      refresh_domains || exit 1
    fi
  fi

  # Copy any docker volumes w/ prior folder name as prefix into current folder name
  read -p "${GREEN}Copy docker volumes?? [N|y] ${NC}" YN
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

  # Refresh docker-compose.yml with the service's docker-compose.yml files
  refresh_compose || exit 1

  echo "Migration complete"
}



