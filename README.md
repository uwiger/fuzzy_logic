fuzzy_logic
===========

A fuzzy logic evaluator in Erlang

This is a touch-up of a library I wrote in 1995.

The main change for now is that I use Tony Rogvall's `inline` transform
in the Crane Controller example, which is inspired by the one described
in Constantin von Altrock's book,

    Fuzzy Logic and Neurofuzzy Applications Explained
    Constantin von Altrock
    Prentice Hall PTR (1995)
    ISBN 0-13-368465-2

There are surely newer books (mine are all from around then).

Example (`test(Iterations, Distance, Angle) -> {Usecs, OutputPower}`):

    Eshell V5.9.2  (abort with ^G)
    1> crane:test(1000,20,0).
    {44.478,  4.444444444444445}
    2> crane:test(1000,20,0).
    {42.684,  4.444444444444445}
    3> crane:test(1000,5,15).
    {46.707,  -7.2}

