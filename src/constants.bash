
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
SCRIPTNAME=$0

# Use the actual ls instead of any alias that could output extra chars
ls=$(which ls)

# If no OADA_HOME, set it to the absolute path of this script
if ! test -d OADA_HOME; then
  OADA_HOME="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
fi
cd "${OADA_HOME}"


