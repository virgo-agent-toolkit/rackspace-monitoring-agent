#!/bin/bash

echo "status Everything is OK"
echo "metric logged_users int 7"
sleep 0.2
echo -n "metric active_processes "
sleep 0.5
echo "int 200"
echo "metric avg_wait_time float 100.7"
echo "metric something string foo bar foo"
sleep 1
echo "metric packet_count gauge 150000"
