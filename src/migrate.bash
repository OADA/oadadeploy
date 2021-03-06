usage_migrate() {
  echo -e "\n\
Migrate from an older Git-based installation to v3+ image-based installation
${GREEN}USAGE: $SCRIPTNAME migrate [path/to/old/server]

STOPS docker from old installation
Copies services-enabled
Copies domains-enabled
Migrates any docker volumes to new volume name for this installation
If you had z_tokens service, it adds that into docker-compose.override.yml
Refreshes docker-compose.yml and docker-compose.override.yml"
}

migrate() {
  local OLD OLDBASE NEWBASE NEWNAME VOLS svc REALDEST OLDBINARYPATH
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
      for i in $(cd "$OLD/services-enabled" && $ls); do
        echo "Copying service ${YELLOW}${i}${NC}"
        REALDEST=$(readlink_crossplatform "$OLD/services-enabled/$i")
        cp -rf "${REALDEST}" ./services/.
      done

      # Check for z_tokens: add it to docker-compose.override.yml if it exists
      if [ -f "./services/z_tokens/docker-compose.yml" ]; then
        echo "Found ${CYAN}z_tokens${NC}, adding it explicitly to docker-compose.override.yml and removing from ./services"
        [ ! -d "./support" ] && mkdir ./support
        # fix paths in z_tokens' docker-compose.yml file
        echo "Replacing any ./services-available/z_tokens paths with ./support/ in z_tokens' docker-compose.yml"
        REPLACED="$(sed 's/services-available\/z_tokens/support/g' services/z_tokens/docker-compose.yml)"
        echo "$REPLACED" > services/z_tokens/docker-compose.yml
        merge_with_override --skip-validate services/z_tokens/docker-compose.yml || exit 1
        echo "Removing any admin service references from docker-compose.override.yml"
        yq -i e 'del(.services.admin)' docker-compose.override.yml || exit 1
        # Move everything (i.e. private keys, etc.) from z_tokens to now be under ./support, and fix the z_tokens paths
        echo "Removing old z_tokens docker-compose.yml now that it is in overrides, and moving any other z_tokens supporting files to ./support"
        rm services/z_tokens/docker-compose.yml && \
        mv -f services/z_tokens/* ./support/. && \
        rm -rf services/z_tokens
        echo "z_tokens merged successfully"
      fi

      # Now do per-service fixups
      for i in $(cd ./services && $ls); do
        echo "Doing initial git pull in services/$i"
        # Do a git pull in case this service has already been updated to oada v3 model
        (cd ./services/$i && git pull && cd ..) || echo "WARNING: Failed to git pull in service $i"

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

          # All the "old" services used container_name, remove that line from their yml:
          echo "Removing container_name so it doesn't conflict w/ old OADA installation"
          REPLACED="$(sed '/container_name/d' services/$i/docker-compose.oada.yml)"
          echo "$REPLACED" > services/$i/docker-compose.oada.yml

        fi
      done

      # Refresh/create services/docker-compose.yml
      refresh_services || exit 1
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
  OLDBASE=$(basename "$OLD")
  NEWBASE=$(basename "$OADA_HOME")
  VOLS=$(docker volume ls -qf name="${OLDBASE}")

  read -p "${GREEN}Copy docker volumes?? [N|y] ${NC}" YN
  if [[ "$YN" =~ y|Y|yes ]]; then
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

  read -p "${GREEN}New OADA puts binary files in binary_data docker volume.  Create this volume and copy in existing http-handler binary data?${NC} [N|y]" YN
  if [[ "$YN" =~ y|Y|yes ]]; then
    NEWNAME="${NEWBASE}_binary_data"
    OLDBINARYPATH="${OLD}/oada-core/http-handler/oada-srvc-http-handler/tmp/oada-cache"
    echo "    Creating volume ${YELLOW}${NEWNAME}${NC} and copying from ${YELLOW}$OLDBINARYPATH${NC}"
    docker volume create "${NEWNAME}" &> /dev/null || echo "ERROR: FAILED TO CREATE VOLUME ${NEWNAME}"
    docker run --rm \
         -v ${OLDBINARYPATH}:/old \
         -v ${NEWNAME}:/new \
         alpine ash -c "cd /old; cp -av . /new" &> /dev/null
    echo "Done copying previous binary data to ${NEWNAME}"
  fi


  read -p "${GREEN}Kafka and zookeoper volumes have to be deleted in order for new kafka to work.  Docker requires the container to be removed in order to remove the container.  Delete kafka and zookeeper containers and volumes? [N|y] ${NC}" YN
  if [[ "$YN" =~ y|Y|yes ]]; then
    for svc in kafka zookeeper; do
      # Check for oada_kafka_1 container
      if [ "$(docker ps -a | grep ${NEWBASE}_${svc}_1 | wc -l)" -eq 1 ]; then
        echo "Removing ${YELLOW}${NEWBASE}_${svc}_1 container"
        docker rm ${NEWBASE}_kafka_1
      fi
      echo "Removing volume ${NEWBASE}_$svc_data"
      docker volume rm ${NEWBASE}_${svc}_data
      if [ "$?" -ne 0 ]; then
        echo "ERROR: Failed to rm ${NEWBASE}_${svc}_data. Continuing."
      fi
    done
  fi

  read -p "${GREEN}WARNING: arangodb needs to upgrade its database.  Make a backup.  Should I upgrade database now? [N|y]" YN
  if [[ "$YN" =~ y|Y|yes ]]; then
    echo "Adding auto-upgrade to arangodb override"
    yq -i e '.services.arangodb.command = [ "arangod", "--server.statistics", "true", "--database.auto-upgrade", "true" ]' docker-compose.override.yml || exit 1
    echo "Bringing up arangodb once to force upgrade"
    docker-compose run --rm arangodb || exit 1
    echo "Removing auto-upgrade from arangodb override"
    yq -i e 'del(.services.arangodb.command)' docker-compose.override.yml || exit 1
  fi

  # Refresh docker-compose.yml with the service's docker-compose.yml files
  refresh_compose || exit 1


  echo "Migration complete"
}



