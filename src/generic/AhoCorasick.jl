#
#   FreeAssAhoCorasick.jl : implement bulk divide check for leading terms of free associative Algebra elements
#   for use e.g. in Groebner Basis computation
#
###############################################################################

const Word = Vector{Int}

struct Queue{T}
  data::Vector{T}
end

function Queue{T}() where T
    return Queue{T}(T[])
end

function enqueue!(q::Queue{T}, val::T) where T
  push!(q.data, val)
end
function dequeue!(q::Queue)
  return popfirst!(q.data)
end
isempty(q::Queue) = isempty(q.data)

@doc """
    AhoCorasickAutomaton

An Aho-Corasick automaton, which can be used to efficiently search for a fixed list of keywords (vectors of Ints) in
arbitrary lists of integers

# Examples
```jldoctest
julia> keywords = [[1, 2, 3, 4], [1, 5, 4], [4, 1, 2], [1, 2]];

julia> aut = Generic.aho_corasick_automaton(keywords);

julia> Generic.search(aut, [10, 4, 1, 2, 3, 4])
AbstractAlgebra.Generic.AhoCorasickMatch(6, 1, [1, 2, 3, 4])
```
""" 
mutable struct AhoCorasickAutomaton
    goto::Vector{Dict{Int,Int}}
    fail::Vector{Int}
    """
    Output stores for each node a tuple (i, k), where i is the index of the keyword k in
    the original list of keywords. If several keywords would be the output of the node, only
    the one with the smallest index is stored
    """
    output::Vector{Tuple{Int,Word}}
end

@doc """
    AhoCorasickMatch(last_position::Int, keyword_index::Int, keyword::Vector{Int})

The return value of searching in a given word with an AhoCorasickAutomaton. Contains the position of the last letter in
the word that matches a keyword in the automaton, an index of the keyword that was matched and the keyword itself.

# Examples
```jldoctest
julia> keywords = [[1, 2, 3, 4], [1, 5, 4], [4, 1, 2], [1, 2]];

julia> aut = Generic.aho_corasick_automaton(keywords);

julia> result = Generic.search(aut, [10, 4, 1, 2, 3, 4])
AbstractAlgebra.Generic.AhoCorasickMatch(6, 1, [1, 2, 3, 4])

julia> Generic.last_position(result)
6

julia> Generic.keyword_index(result)
1

julia> Generic.keyword(result)
4-element Vector{Int64}:
 1
 2
 3
 4
```
""" 
struct AhoCorasickMatch
    last_position::Int
    keyword_index::Int
    keyword::Word
end

"""
returns the last position of the match in the word that was searched
"""
function last_position(match::AhoCorasickMatch)
    return match.last_position
end

"""
returns the index of the keyword in the corresponding aho corasick automaton
"""
function keyword_index(match::AhoCorasickMatch)
    return match.keyword_index
end

"""
returns the keyword corresponding to the match
"""
function keyword(match::AhoCorasickMatch)
    return match.keyword
end

function aho_corasick_match(last_position::Int, keyword_index::Int, keyword::Word)
    return AhoCorasickMatch(last_position, keyword_index, keyword)
end

Base.hash(m::AhoCorasickMatch, h::UInt) = hash(m.last_position, hash(m.keyword_index, 
                                                            hash(m.keyword, h)))
function ==(m1::AhoCorasickMatch, m2::AhoCorasickMatch)
    return m1.last_position == m2.last_position &&
           m1.keyword_index == m2.keyword_index &&
           m1.keyword == m2.keyword
end

function AhoCorasickAutomaton(keywords::Vector{Word})
    automaton = AhoCorasickAutomaton([], [], [])
    construct_goto!(automaton, keywords)
    construct_fail!(automaton)
    return automaton
end

function aho_corasick_automaton(keywords::Vector{Word})
    return AhoCorasickAutomaton(keywords)
end

function lookup(automaton::AhoCorasickAutomaton, current_state::Int, next_letter::Int)
    ret_value = get(automaton.goto[current_state], next_letter, nothing)
    if current_state == 1 && isnothing(ret_value)
        return 1
    end
    return ret_value
end


function Base.length(automaton::AhoCorasickAutomaton)
    return length(automaton.goto)
end

function new_state!(automaton)
    push!(automaton.goto, Dict{Int,Int}())
    push!(automaton.output, (typemax(Int), []))
    push!(automaton.fail, 1)
    return length(automaton.goto)
end

function enter!(automaton::AhoCorasickAutomaton, keyword::Word, current_index)
    current_state = 1
    for c in keyword
        current_state = get!(automaton.goto[current_state], c) do
            new_state!(automaton)
        end
    end
    if automaton.output[current_state][1] > current_index
        automaton.output[current_state] = (current_index, keyword)
    end
end

function construct_goto!(automaton::AhoCorasickAutomaton, keywords::Vector{Word})
    new_state!(automaton)
    for (current_index, keyword) in enumerate(keywords)
        enter!(automaton, keyword, current_index)
    end
end

function construct_fail!(automaton::AhoCorasickAutomaton)
    q = Queue{Int}()
    for v in values(automaton.goto[1])
        enqueue!(q, v)
    end
    while !isempty(q)
        current_state = dequeue!(q)
        for (k, new_state) in automaton.goto[current_state]
            enqueue!(q, new_state)
            state = automaton.fail[current_state]
            while (s = lookup(automaton, state, k)) === nothing
                state = automaton.fail[state]
            end
            automaton.fail[new_state] = s
            if automaton.output[new_state][1] >
               automaton.output[automaton.fail[new_state]][1]
               automaton.output[new_state] = automaton.output[automaton.fail[new_state]] 
            end

        end
    end
end

@doc """
    insert_keyword!(aut::AhoCorasickAutomaton, keyword::Word, index::Int)

Insert a new keyword into a given Aho-Corasick automaton to avoid having to rebuild the entire
automaton.
""" 
function insert_keyword!(aut::AhoCorasickAutomaton, keyword::Word, index::Int)
    enter!(aut, keyword, index)
    aut.fail = ones(Int, length(aut.goto))
    construct_fail!(aut)
end

@doc """
    search(automaton::AhoCorasickAutomaton, word::Word)

Search for the first occurrence of a keyword that is stored in `automaton` in the given `word`.
""" 
function search(automaton::AhoCorasickAutomaton, word::Word)
    current_state = 1
    result = AhoCorasickMatch(typemax(Int), typemax(Int), [])
    for i in 1:length(word)
        c = word[i]
        while true
            next_state = lookup(automaton, current_state, c)
            if next_state !== nothing
                current_state = next_state
                break
            else
                current_state = automaton.fail[current_state]
            end
        end
        if automaton.output[current_state][1] < result.keyword_index
            result = AhoCorasickMatch(
                i,
                automaton.output[current_state][1],
                automaton.output[current_state][2],
            )
        end
    end
    if isempty(result.keyword)
        return nothing
    end
    return result
end
