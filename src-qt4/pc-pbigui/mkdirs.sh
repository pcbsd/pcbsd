#!/bin/sh

# Make sure the following dirs exist
doDirs="/usr/local/etc/xdg/menus /usr/local/etc/xdg/applications-merged /usr/local/share/desktop-directories /usr/local/share/applications /usr/local/share/mime/application"

for i in $doDirs
do
  if [ ! -d "$i" ] ; then
     echo "Creating directory: ${i}"
     mkdir -p ${i}
  fi
done
