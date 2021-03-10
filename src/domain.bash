usage_domain() {
  echo -e "\n\
Add a new domain or refresh domains/docker-compose.yml
${GREEN}USAGE: $SCRIPTNAME domain [add|refresh|primary] [-y] <domain>

    ${CYAN}add [-y] <domain>${NC}\t\tAdd new domain, -y to accept all defaults
    ${CYAN}refresh${NC}\tRefresh docker-compose.yml from existing domains/ directory
    ${CYAN}primary <domain>${NC}\tSet primary domain for your deployment (in .oadadeploy/primarydomain)"
}

# Run the domain-add within the admin container so it doesn't have to keep dropping into
# to run jq, node, oada-certs, etc.
domain_add() {
  local DOMAIN
  if [ "$#" -gt 0 ]; then
    # Domain is last command-line arg (this avoids checking for -y)
    DOMAIN=${@: -1}
  fi
  admin -it /support/domains/domain-add $@
  # Save the first domain they created as the primary domain so subsequent refreshes are consistent
  if [ ! -f ".oadadeploy/primarydomain" ]; then
    echo $DOMAIN > .oadadeploy/primarydomain
  fi
  refresh_domains
}

primary_domain() {
  # Test if this domain exists in the domains folder
  if [ ! -d "domains/$1" ]; then
    echo "WARNING: requested primary domain ${YELLOW}$1${NC} does not exist in domains folder"
  fi
  echo "$1" > .oadadeploy/primarydomain
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
    primary)
      shift
      primary_domain $@
    ;;
  esac
}
