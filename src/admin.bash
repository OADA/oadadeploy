usage_admin() {
  echo -e "\n\
Execute administrative command

${GREEN}USAGE: $SCRIPTNAME admin [devusers|extendToken|useradd|bash]
    devusers\t[add|rm] dummy users/tokens for development (insecure)
    token\tRuns the token.js script in auth (create, extend, revoke)
    useradd\tRuns the add script in users
    bash\t\tGives you a bash shell in admin container
    *\t\t\tRuns arbitrary command in admin container"
}

add_devusers() {
  local res cmd
  echo "INSECURE: adding default users/tokens to your docker-compose.overrides.yml (in startup)"
  cmd="del(.services.startup.environment.[] | select(. == \"arangodb__ensureDefaults*\"))"
  cmd="${cmd} | .services.startup.environment += [ \"arangodb__ensureDefaults=true\" ]"
  res=$(yq e "${cmd}" docker-compose.override.yml 2>&1 > new.docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Failed to add devusers environment variable to startup in override.  Failed attempt is in new.docker-compose.override.yml"
    echo "$res"
    exit 1
  fi
  mv new.docker-compose.override.yml docker-compose.override.yml
  echo "${YELLOW}docker-compose up -d startup${NC}"
  docker-compose up -d startup
}

rm_devusers() {
  local res
  echo "Removing: default users/tokens"
  cmd="del(.services.startup.environment.[] | select(. == \"arangodb__ensureDefaults*\"))"
  cmd="${cmd} | .services.startup.environment += [ \"arangodb__ensureDefaults=false\" ]"
  res=$(yq e "${cmd}" docker-compose.override.yml 2>&1 > new.docker-compose.override.yml)
  if [ "$?" -ne 0 ]; then
    echo "Failed to set devusers environment variable to false for startup in override.  Failed attempt is in new.docker-compose.override.yml"
    echo "$res"
    exit 1
  fi
  mv new.docker-compose.override.yml docker-compose.override.yml
  echo "${YELLOW}docker-compose up -d startup${NC}"
  docker-compose up -d startup
}

admin() {
  local CMD
  CMD=$1
  shift
  case $CMD in
    # add|rm the dummy tokens/users from db
    devusers)
      case $1 in 
        add)
          add_devusers
        ;;
        rm)
          rm_devusers
        ;;
        *) echo -e "USAGE: $SCRIPTNAME admin devusers [add|rm]" ;;
      esac
    ;;

    # create, extend, and revoke tokens for users
    token)
      echo "${YELLOW}docker-compose exec auth yarn run token $@${NC}"
      docker-compose exec auth yarn run token $@
    ;;

    # add users
    useradd) 
      echo "${YELLOW}docker-compose exec users yarn run add $@${NC}"
      docker-compose exec users yarn run add $@
    ;;

    # run admin container, interactive
    -it|-ti)
      echo "${YELLOW}docker run --rm -it -v ${PWD}:/code oada/admin $@${NC}"
      docker run --rm -it -v ${PWD}:/code oada/admin $@
    ;;

    # run admin container w/ passthru commands, mapping . to /code, non-interactive
    *)
      # If they pass only "bash", default make it interactive
      if [ "$#" -eq 0 ] && [ "$CMD" == "bash" ]; then
        docker run --rm -it -v ${PWD}:/code oada/admin ${CMD} $@
      else
        echo "${YELLOW}docker run --rm oada/admin ${CMD} $@${NC}"
        docker run --rm -v ${PWD}:/code oada/admin ${CMD} $@
      fi

    ;;
  esac
}


