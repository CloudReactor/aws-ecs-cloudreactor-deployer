#!/bin/bash

# bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

echo "Starting ..."

if [ -z "$TEMP_FILE_DIR" ]
  then
    TEMP_FILE_DIR="~/scratch"
fi


echo "Hello!" > "$TEMP_FILE_DIR/hello.txt"
cat "$TEMP_FILE_DIR/hello.txt"
exec echo "Done!"
