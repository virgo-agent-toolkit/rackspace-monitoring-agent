#!/bin/bash

echo "status Invalid metric lines 3"
echo "metric metric8 int 100 200 bytes"
echo "metric foo int"
echo "metric metric1 intfoo 10"
echo "metric metric2 double 10"
echo "metric metric3 sometype 10"
echo "metric foo bar foo"
echo "metric foo"
echo "metric metric7 string test bar"
