#! /bin/bash

cd source;

rdmd --force -d -Dd../docs -de -op -w -main -I. etcetera/collection/package.d;
