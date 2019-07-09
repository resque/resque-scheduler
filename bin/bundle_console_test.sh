#! /bin/sh

if echo "exit" | bundle console > /dev/null ; then
  echo 'bundle console succeeded'
else
  echo 'bundle console failed'
  exit 1
fi
