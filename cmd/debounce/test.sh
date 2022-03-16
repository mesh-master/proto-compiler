#! /bin/bash

stdbuf -o0 showkey -a | ./debounce "$@" | cat -
