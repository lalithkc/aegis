#!/bin/bash
# usage: run.sh <command...>   runs the command inside the Cadence/Mentor tcsh environment
cd $PROJ_ROOT
printf "source env.csh\n%s\n" "$*" > .run_$$.csh
tcsh -f .run_$$.csh; rc=$?; rm -f .run_$$.csh; exit $rc
