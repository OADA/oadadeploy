
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
SCRIPTNAME=$0

# Use the actual ls instead of any alias that could output extra chars
ls=$(which ls)

readlink_crossplatform() {
  local P
  # First try it as Linux has it (with -f)
  P=$(readlink -f $1 2> /dev/null)
  if [ "$?" -ne 0 ]; then
    # POSIX failed, try mac readlink:
    P=$(readlink $1 2> /dev/null)
    if [ "$?" -ne 0 ]; then
      return 1
    fi
  fi
  echo "$P"
  return 0
}

# If no OADA_HOME, set it to the absolute path of this script
if ! test -d "$OADA_HOME"; then
  SCRIPTPATH="$0"
  if [ -L "$SCRIPTPATH" ]; then
    SCRIPTPATH=$(dirname $(readlink_crossplatform $SCRIPTPATH))
  else
    # Otherwise, to be safe for symlinks in the path somewhere, use the dirname pwd -P trick:
    SCRIPTPATH=$(cd $(dirname "$SCRIPTPATH") > /dev/null 2>&1; pwd -P)
  fi

  OADA_HOME="$SCRIPTPATH"
fi

cd "${OADA_HOME}"


