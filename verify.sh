#!/bin/bash

file=`md5 -q $1`

echo "Checking file: $1"
echo "Using MD5: $2"
echo $file

if [ $file != $2 ]
then
  echo "md5 sums mismatch"
  exit 1
else
  echo "checksums OK"
fi

