# factori

This is an assembly version of the mbal i(Maxime Bellousov) algorithm to find
factors of one big integer. The big integer (428987894557991123) is hardcoded
in the algorithm to produce the **CALCULATED** factors 218323891 * 1964915028.

> ```Author : Toon Leijtens / Date : 28.07.2019 / Carouge - Genève```  

## note from the programmer

This assembly script was created for OSX. You will need the following:

* nasm; NASM version 2.14.02 compiled on Dec 27 2018 (or better)
* ld; BUILD 18:16:53 Apr  5 2019 (or better)

to build use the follwing:

$ nasm -fmacho64 -g -O0 factori.asm -o factori.o
$ ld -macosx_version_min 10.8.0 -o factori factori.o -lSystem

to run:

./factori

## result

The overall compute time, including printing of 3 numbers is 1.990s on a 2017
macbook pro.
