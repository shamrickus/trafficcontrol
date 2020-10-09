#!/bin/bash

for f in `find . -type f`
do
	if [[ "$f" == *.ts ]]
	then
		mv $f ${f/.ts/.js}
	fi
done
