#! /bin/bash

_echo() {
  local n=${1:-3}
  local sleep=${2:-1}
  (
    for ((i = 1; i <= $n; i++)); do
      now=$(date +%s)
      echo "$i: $now"
      sleep ${sleep}s
    done
  )
  echo "Sleep 2s"
  sleep 2s
  echo "Run again"
  (
    for ((i = 1; i <= $n; i++)); do
      now=$(date +%s)
      echo "$i: $now"
      sleep ${sleep}s
    done
  )
}

#
_echo 5 1 | ./debounce -t 1020 | cat
