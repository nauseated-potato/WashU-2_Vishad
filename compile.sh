#!/usr/bin/env bash

ghdl -a "$@"

last_file="${!#}"
top_entity="$(basename "${last_file%.*}")"

ghdl -e "$top_entity"

ghdl -r "$top_entity" --wave=out.ghw
