#!/bin/bash

# bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

echo "Starting ..."
echo "Hello!" > ~/scratch/hello.txt
cat ~/scratch/hello.txt
exec echo "Done!"
