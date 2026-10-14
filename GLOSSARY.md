# Glossary

## Dictionary

A normalised collection of candidate words evaluated against a Puzzle. Only
words containing lowercase alphabetic characters and meeting the minimum word
size are considered valid candidates.

## Letter Pool

The complete set of allowed characters for a Puzzle, consisting of between four
and nine unique lowercase letters. Formed by combining the Mandatory Letter and
Other Letters.

_Avoid_: Characters, Alphabet

## Mandatory Letter

The single character that must be present in every valid word found by the
Solver.

## Nine Letters

A puzzle mode where words are capped at nine characters and each character in
the Letter Pool may be used at most once.

_Avoid_: Non-repeats

## Other Letters

The set of allowed characters in the Letter Pool excluding the Mandatory Letter.
In the web interface, this comprises three to eight unique lowercase letters.

## Puzzle

The core domain specification of constraints for a word search. Comprises a
Mandatory Letter, a Letter Pool, a Word Size, and a Repeats flag.

## Repeats

A puzzle mode (such as the NYT Spelling Bee) where letters in the Letter Pool
may be reused multiple times within a single word, with no upper bound on word
length.

## Smart Constructor

A design pattern where the raw data constructor is hidden from external modules
and creation is mediated by a validating factory function (`mkPuzzle`).

## Solver

The matching algorithm that filters a Dictionary against Puzzle constraints and
produces sorted words grouped by length.

## Validation Error

A structured failure value produced when puzzle inputs violate domain
invariants, such as out-of-range word sizes, non-unique characters, or empty
inputs.

## Word Group

A collection of matching puzzle solution words sharing an identical length,
sorted alphabetically.

## Word Size

The minimum length constraint for a valid word, bounded between four and nine
characters inclusive.
