#!/usr/bin/env bash

cd submodules

cd paramcoq
make coq install
if [ $? -eq 0 ]
then
    echo "paramcoq looks up-to-date"
else
    echo "(re)building paramcoq"
    git clean -dfx
    make coq
    make install
fi
cd ..

cd coq-ext-lib
coq_makefile -f _CoqProject -o Makefile
make all && make install
if [ $? -eq 0 ]
then
    echo "coq-ext-lib looks up-to-date"
else
    echo "(re)building coq-ext-lib"
    git clean -dfx
    coq_makefile -f _CoqProject -o Makefile
    make all
    make install
fi
cd ..

cd SquiggleEq
make all && make install
if [ $? -eq 0 ]
then
    echo "Squiggleeq looks up-to-date"
else
    echo "(re)building SquiggleEq"
    git clean -dfx
    make all
    make install
fi
cd ..

cd Equations
coq_makefile -f _CoqProject -o Makefile
make all && make install
if [ $? -eq 0 ]
then
    echo "Equations looks up-to-date"
else
    echo "(re)building Equations"
    git clean -dfx
    make all
    make install
fi
cd ..

cd Template-Coq
./configure.sh local
make all && make install
if [ $? -eq 0 ]
then
    echo "MetaCoq looks up-to-date"
else
    echo "(Re)building MetaCoq"
    git clean -dfx
    ./configure.sh local
    make all
    make install
fi
