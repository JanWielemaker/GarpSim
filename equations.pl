:- module(equations,
          [ equations//1
          ]).
:- use_module(library(dcg/high_order)).
:- use_module(library(http/html_write)).
:- use_module(library(http/js_write)).
:- use_module(library(http/html_head)).
:- use_module(library(dcg/basics)).

:- html_resource(mathlive,
                 [ virtual(true),
                   ordered(true),
                   requires([ 'https://unpkg.com/mathlive',
                              %'/garp/mathlive.js',
                              '/garp/equations.js'
                            ])
                 ]).
:- html_resource('https://unpkg.com/mathlive',
                 [ mime_type(text/javascript)
                 ]).

%!  equations(+Equations:list)//
%
%   Render a list of equations as a div holding mathlive expressions.

equations(Eqs) -->
    html_requires(mathlive),
    html(div([id(equations), class(equations)],
             \sequence(equation, Eqs))),
    js_script({|javascript||
               ml_init();
              |}).


equation(Eq) -->
    { phrase(eq_to_mathjax(Eq), Codes),
      string_codes(String, Codes),
      pp(String)
    },
    html(div(class(equation),
             'math-field'(String))).

eq_to_mathjax(Left := Right) ==>
    !,
    quantity(Left),
    "=",
    expression(Right).

quantity(Q), compound(Q), Q =.. [A,E] ==>
    format('\\prop{~w}{~w}', [A,E]).
quantity(Q), atom(Q) ==>
    format('\\variable{~w}', [Q]).
quantity(Q), number(Q) ==>
    format('\\placeholder[c]{~w}', [Q]).

expression(A + B) ==> expression(A), " + ", expression(B).
expression(A - B) ==> expression(A), " - ", expression(B).
expression(A * B) ==> expression(A), " \\cdot ", expression(B).
expression(A / B) ==> "\\frac{", expression(A), "}{", expression(B), "}".
expression(Q), ground(Q) ==> quantity(Q).

format(Fmt, Args, Head, Tail) :-
    format(codes(Head, Tail), Fmt, Args).


		 /*******************************
		 *            PARSE		*
		 *******************************/

parse_latex(String, Formula) :-
    string_codes(String, Codes),
    phrase(latex(eos, Formula), Codes).

latex(End, List) -->
    is_end(End),
    !,
    { List = [] }.
latex(End, [H|T]) -->
    latex_1(End, H),
    latex(End, T).

latex_1(_, Token) --> latex_cmd(Token), !.
latex_1(End, String) --> string(Codes), ends_string(End), !, {string_codes(String, Codes)}.

ends_string(End) --> is_end(End), !.
ends_string(_), "\\" --> "\\", !.
ends_string(_), "{" --> "{", !.
ends_string(_), "}" --> "}", !.

is_end(eos) --> eos, !.
is_end(String), [C]--> [C], {string_code(_, String, C)}, !.

latex_cmd(Command) -->
    "\\", ltx_name(Name), ltx_args(Name, Args),
    { compound_name_arguments(Command, Name, Args) }.

ltx_name(Name) -->
    csym(Name).

ltx_args(prop, Args) ==> ltx_nargs(2, Args).
ltx_args(_,    Args) ==> curl_args(Args).

ltx_nargs(0, []) --> !.
ltx_nargs(N, [H|T]) --> ltx_arg(H), {N1 is N-1}, ltx_nargs(N1, T).

ltx_arg(Arg) --> curl_arg(Arg), !.

curl_args([H|T]) -->
    peek("{"),
    !,
    curl_arg(H),
    curl_args(T).
curl_args([]) -->
    [].

curl_arg(Arg) --> "{", !, latex("}", Arg), "}".

peek(C), [C] --> [C].
