#!/bin/sh

echo "status Everything is OK"
for i in `seq 1 10000`; do
  echo "metric logged_users_${i} int 7"
done
echo "metric logged_users_aaa int 7"
