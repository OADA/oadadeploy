usage_domain() {
  echo -e "\n\
Add a new domain or refresh domains/docker-compose.yml
${GREEN}USAGE: $SCRIPTNAME domain [add|refresh] [-y] <domain>

    ${CYAN}add [-y] <domain>${NC}\t\tAdd new domain, -y to accept all defaults
    ${CYAN}refresh${NC}\tRefresh docker-compose.yml from existing domains/ directory"
}

# Run the domain-add within the admin container so it doesn't have to keep dropping into
# to run jq, node, oada-certs, etc.
domain_add() {
  admin -it /support/domains/domain-add $@ $DOMAIN
}

domain() {
  # Check for help
  [[ $@ =~ -h|--help|help|\? ]] && usage domain
  case $1 in 
    add) 
      shift
      domain_add $@
    ;;
    refresh) 
      refresh_domains
    ;;
  esac
}
