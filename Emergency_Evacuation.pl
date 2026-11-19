% Dynamic predicates so blocked paths can be updated live during practical exam
:- dynamic blocked_edge/2.
:- dynamic blocked_loc/1.
% -------------------------------------------------------------------------
% 1. BUILDING LOCATIONS (8 Locations: Rooms, Corridors, Staircase, Exits)
% -------------------------------------------------------------------------
location('Room A',      room).
location('Room B',      room).
location('Room C',      room).
location('Corridor 1',  corridor).
location('Corridor 2',  corridor).
location('Staircase 1', staircase).
location('Exit 1',      exit).
location('Exit 2',      exit).

exit(Loc) :- location(Loc, exit).

% -------------------------------------------------------------------------
% 2. CONNECTIONS WITH RISK LEVELS: edge(Location1, Location2, RiskLevel)
%    Lower RiskLevel = Safer corridor (1 = Very Safe, 5 = High Risk)
% -------------------------------------------------------------------------
edge('Room A',      'Corridor 1',  2).
edge('Corridor 1',  'Staircase 1', 1).
edge('Staircase 1', 'Exit 1',      1).
edge('Corridor 1',  'Room B',      3).
edge('Room B',      'Exit 2',      2).
edge('Room A',      'Corridor 2',  5).
edge('Corridor 2',  'Exit 2',      4).
edge('Room C',      'Corridor 2',  2).

% -------------------------------------------------------------------------
% 3. DEFAULT BLOCKED CONNECTION (Matches Sample Input)
% -------------------------------------------------------------------------
blocked_edge('Corridor 1', 'Staircase 1').

% -------------------------------------------------------------------------
% 4. GRAPH & CONSTRAINT HANDLING RULES
% -------------------------------------------------------------------------

% Connections are bidirectional (undirected graph)
connected(X, Y, Risk) :- edge(X, Y, Risk).
connected(X, Y, Risk) :- edge(Y, X, Risk).

% Blocked connections apply in both directions
is_blocked_edge(X, Y) :- blocked_edge(X, Y).
is_blocked_edge(X, Y) :- blocked_edge(Y, X).

% A move is safe only if connected and neither nodes nor corridor are blocked
safe_move(X, Y, Risk) :-
    connected(X, Y, Risk),
    \+ blocked_loc(X),
    \+ blocked_loc(Y),
    \+ is_blocked_edge(X, Y).

% -------------------------------------------------------------------------
% 5. PATH SEARCH (DEPTH-FIRST SEARCH WITH CYCLE PREVENTION)
% -------------------------------------------------------------------------

% Base case: Reached a safe exit
find_route(Current, _, [Current], Current, 0) :-
    exit(Current),
    \+ blocked_loc(Current).

% Recursive case: Move to an unvisited safe neighbor and accumulate risk
find_route(Current, Visited, [Current | RestPath], ExitReached, TotalRisk) :-
    \+ exit(Current),
    safe_move(Current, Next, StepRisk),
    \+ member(Next, Visited),
    find_route(Next, [Next | Visited], RestPath, ExitReached, SubRisk),
    TotalRisk is StepRisk + SubRisk.

% -------------------------------------------------------------------------
% 6. ROUTE OPTIMIZATION (LOWEST RISK FIRST, FEWEST STEPS AS TIE-BREAKER)
% -------------------------------------------------------------------------

all_safe_routes(Start, SortedRoutes) :-
    findall(
        route(Risk, Steps, Path, Exit),
        (
            find_route(Start, [Start], Path, Exit, Risk),
            length(Path, Len),
            Steps is Len - 1
        ),
        Routes
    ),
    sort(Routes, SortedRoutes).

% -------------------------------------------------------------------------
% 7. DISPLAY & OUTPUT FORMATTING
% -------------------------------------------------------------------------

print_route([Last]) :-
    write(Last), nl.
print_route([Head | Tail]) :-
    write(Head), write(' -> '),
    print_route(Tail).

print_alternatives([]) :- !.
print_alternatives(Alts) :-
    nl,
    write('Alternative Safe Route(s):'), nl,
    forall(
        member(route(Risk, Steps, Path, Exit), Alts),
        (
            format('  - [Exit: ~w | Risk: ~w | Steps: ~w] ', [Exit, Risk, Steps]),
            print_route(Path)
        )
    ).

% Main predicate to plan evacuation from any starting location
evacuate(Start) :-
    nl,
    write('=========================================='), nl,
    write('       EMERGENCY EVACUATION PLANNER       '), nl,
    write('=========================================='), nl,
    (   \+ location(Start, _)
    ->  format('Error: "~w" is not a valid building location.~n', [Start])
    ;   format('Starting Location: ~w~n', [Start]),
        all_safe_routes(Start, Routes),
        (   Routes = [route(MinRisk, Steps, BestPath, BestExit) | Alternatives]
        ->  write('Route Found:'), nl,
            print_route(BestPath), nl,
            format('Destination: ~w~n', [BestExit]),
            format('Total Risk: ~w | Total Steps: ~w~n', [MinRisk, Steps]),
            write('Status: Route found.'), nl,
            print_alternatives(Alternatives)
        ;   write('Route Found: None'), nl, nl,
            write('Destination: None'), nl,
            write('Status: No safe route available!'), nl
        )
    ),
    write('=========================================='), nl, nl.

% -------------------------------------------------------------------------
% 8. LIVE MODIFICATION HELPERS (FOR PRACTICAL EXAM / VIVA)
% -------------------------------------------------------------------------

block_connection(A, B) :-
    (   is_blocked_edge(A, B) -> true ; assertz(blocked_edge(A, B)) ),
    format('>> Blocked connection: ~w <-> ~w~n', [A, B]).

unblock_connection(A, B) :-
    retractall(blocked_edge(A, B)),
    retractall(blocked_edge(B, A)),
    format('>> Unblocked connection: ~w <-> ~w~n', [A, B]).

block_location(Loc) :-
    (   blocked_loc(Loc) -> true ; assertz(blocked_loc(Loc)) ),
    format('>> Blocked location: ~w~n', [Loc]).

unblock_location(Loc) :-
    retractall(blocked_loc(Loc)),
    format('>> Unblocked location: ~w~n', [Loc]).

reset_blocks :-
    retractall(blocked_edge(_, _)),
    retractall(blocked_loc(_)),
    assertz(blocked_edge('Corridor 1', 'Staircase 1')),
    write('>> Reset to default: Only Corridor 1 <-> Staircase 1 is blocked.'), nl.

show_status :-
    write('Blocked Connections:'), nl,
    (   blocked_edge(_, _)
    ->  forall(blocked_edge(A, B), format('  - ~w <-> ~w~n', [A, B]))
    ;   write('  None'), nl
    ),
    write('Blocked Locations:'), nl,
    (   blocked_loc(_)
    ->  forall(blocked_loc(L), format('  - ~w~n', [L]))
    ;   write('  None'), nl
    ).

% -------------------------------------------------------------------------
% 9. ONE-COMMAND DEMO (RUNS ALL 3 REQUIRED TEST CASES)
% -------------------------------------------------------------------------

run_tests :-
    nl,
    write('*** TEST CASE 1: Sample Input (Corridor 1 - Staircase 1 Blocked) ***'), nl,
    reset_blocks,
    evacuate('Room A'),

    write('*** TEST CASE 2: Staircase Unblocked (Multiple Exits, Lowest Risk) ***'), nl,
    unblock_connection('Corridor 1', 'Staircase 1'),
    evacuate('Room A'),

    write('*** TEST CASE 3: Corridor 2 Blocked (No Safe Route from Room C) ***'), nl,
    reset_blocks,
    block_location('Corridor 2'),
    evacuate('Room C'),

    reset_blocks.

