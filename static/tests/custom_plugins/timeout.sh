#!/bin/bash

sleep 500&
PID=$!
trap "kill $PID" EXIT
