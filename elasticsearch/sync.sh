#!/bin/bash
set -e
# Usage: sync.sh <target-elasticsearch-url>

input=http://prod.elasticsearch.com:9200
target=${1-"dev.elasticsearch.com:9200"}
output=http://${target##*/}

echo "$input -> $output [$target]"

for index in $(curl -sL "$input/_cat/indices?h=index" | sed -e '/^\..*/d'); do
  {
    echo "--------- $index ---------"
    elasticdump \
      --input=$input/$index \
      --output=$output/$index \
      --type mapping \
      && echo "~~~~~~~~~ done ~~~~~~~~~" \
      || echo "~~~~~~~~~ failed ~~~~~~~~~"
  } 2>&1 | buffer -m 1M | cat & pids="$pids $!"
done
wait $pids
