#!/bin/bash

string=$1
wget -q -O tmp.html "$string"

# Echo out track number
awk '/album:track/ {match($0, /"music:album:track" content="[0-9]+"/, arr); match(arr[0], /[0-9]+/, tn); print tn[0]}' tmp.html

# string=$(grep background: tmp.html | cut '-d/' -f 3,4,5 | cut '-d)' -f1)
# wget -q -O cover.jpg "$string"

rm -f tmp.html
