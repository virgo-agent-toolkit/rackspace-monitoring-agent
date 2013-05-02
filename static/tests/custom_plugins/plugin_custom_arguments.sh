#!/bin/bash

echo "status arguments test"
i=0

for var in "$@"
do
    echo "metric $var string $i"
    i=$((i+1))
done
