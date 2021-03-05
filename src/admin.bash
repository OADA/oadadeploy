usage_admin() {
  echo -e "\n\
Execute administrative command

${GREEN}USAGE: $SCRIPTNAME admin [devusers|extendToken|useradd|bash]
    devusers\t[add|rm] dummy users/tokens for development (insecure)
    extendToken\tRuns the extendToken script in auth
    useradd\tRuns the add script in users
    bash\t\tGives you a bash shell in admin container
    *\t\t\tRuns arbitrary command in admin container"
}

admin() {
  local CMD
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

    # run admin container, interactive
    -it|-ti)
      echo "${YELLOW}docker run --rm -it -v ${PWD}:/code oada/admin $@${NC}"
      docker run --rm -it -v ${PWD}:/code oada/admin $@
    ;;

    # run admin container w/ passthru commands, mapping . to /code, non-interactive
    *)
      echo "${YELLOW}docker run --rm oada/admin ${CMD} $@${NC}"
      docker run --rm -v ${PWD}:/code oada/admin ${CMD} $@
    ;;
  esac
}


