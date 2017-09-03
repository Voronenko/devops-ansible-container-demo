#!/bin/bash

git config -f .projmodules --get-regexp '^submodule\..*\.path$' > tempfile

while read -u 3 path_key path
do
    url_key=$(echo $path_key | sed 's/\.path/.url/')
    url=$(git config -f .projmodules --get "$url_key")
    if [ ! -d "$path" ]; then
      rm -rf $path
      git clone $url $path
      echo "$path has been initialized"
    fi

done 3<tempfile

rm tempfile

echo Project was checked out
