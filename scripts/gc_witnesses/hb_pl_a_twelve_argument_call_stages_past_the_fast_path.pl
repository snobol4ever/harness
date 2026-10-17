:- initialization(main).
p(A,B,C,D,E,F,G,H,I,J,K,L, X) :- X is A+B+C+D+E+F+G+H+I+J+K+L.
q(N, S) :- p(N,1,2,3,4,5,6,7,8,9,10,11, S).
main :- q(1, S1), q(2, S2), q(3, S3), write(S1-S2-S3), nl, halt.
