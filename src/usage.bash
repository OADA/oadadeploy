usage() {
  case $1 in 
    migrate) usage_migrate ;;
    upgrade) usage_upgrade ;;
    admin) usage_admin ;;
    init) usage_init ;;
    domain) usage_domain ;;
    service) usage_service ;;
    refresh) usage_refresh;;
    *)
      echo -e "\n\
Manage local oada installation and supporting services.

${GREEN}USAGE: $SCRIPTNAME [COMMAND] [ARGS...]${NC}
OADA Commands: 
   ${CYAN}init${NC}\t\tInitialize current directory w/ oada and supporting structure
   ${CYAN}upgrade${NC}\tUpgrade current oada to a different version
   ${CYAN}admin${NC}\tRun oada admin command, refer to admin help for specific commands
   ${CYAN}domain${NC}\tAdd a domain or refresh domains/docker-compose.yml from domains
   ${CYAN}service${NC}\tInstall or upgrade services, or refresh docker-compose.yml from services
   ${CYAN}refresh${NC}\tRefresh docker-compose.yml

docker-compose commands supported as passthru w/ bash-completion (refer to docker-compose documentation):
   ${YELLOW}build, config, create, down, events, exec, help, images, kill, logs, pause,
   port, ps, pull, push, restart, rm, run, scale, start, stop, top, unpause, up${NC}

OADA_HOME env var sets which oada deployment used ${OADA_HOME}."

    ;;
  esac
  exit 1
}



