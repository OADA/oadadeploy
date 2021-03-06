array_has_no_flags() {
  for arg in $@; do
    [[ "$arg" =~ ^- ]] && return 1; # found a flag, return false
  done
  return 0; # did not find it, return true (bash true is  0)
}
compose() {
  local command=$1 DEFAULTFLAGS
  shift;
  DEFAULTFLAGS=""

  # If no flags passed, lets set some defaults:
  if array_has_no_flags $@; then
    case $command in

      # Default logs to -f --tail=200
      logs) 
        DEFAULTFLAGS="-f --tail=200"
      ;;

      # Add default "-d" to up
      up)
        DEFAULTFLAGS="-d"
      ;;
    esac
  fi
  echo -e "${YELLOW}docker-compose $command ${DEFAULTFLAGS} $@ ${NC}"
  docker-compose $command ${DEFAULTFLAGS} $@
}
