module Puzzle exposing
    ( Puzzle, WordGroup, ValidationError(..)
    , mkPuzzle, mkPuzzleFromString, size, mandatory, letters, repeats
    , validateSize, validateLetters, errorToString
    , accepts, solve, solveWords, nineLetters, spellingBee
    )

{-| Word puzzle core domain model, validators, and bitmask solver.
Port of Haskell `WordPuzzle` module.


# Types

@docs Puzzle, WordGroup, ValidationError


# Construction & Accessors

@docs mkPuzzle, mkPuzzleFromString, size, mandatory, letters, repeats


# Validation

@docs validateSize, validateLetters, errorToString


# Solving

@docs accepts, solve, solveWords, nineLetters, spellingBee

-}

import Bitwise
import Dict
import Dictionary exposing (WordIndex)
import Set
import Validation exposing (Validation)


{-| Minimum allowed word length and letter pool lower bound.
-}
minWordSize : Int
minWordSize =
    4


{-| Maximum letter pool upper bound.
-}
maxPoolSize : Int
maxPoolSize =
    9


{-| Opaque Puzzle configuration. The constructor is not exported.
Use mkPuzzle or mkPuzzleFromString to construct a validated Puzzle.
-}
type Puzzle
    = Puzzle
        { size : Int
        , mandatory : Char
        , mandString : String
        , mandMask : Int
        , letters : String
        , repeats : Bool
        , poolMask : Int
        }


{-| Words matching the puzzle grouped by length.
-}
type alias WordGroup =
    { length : Int
    , words : List String
    }


{-| Domain validation errors accumulated during puzzle construction.
-}
type ValidationError
    = InvalidSize ( Int, Int ) Int
    | InvalidLetters String
    | SizeNotANumber String
    | InvalidMandatory Char
    | MissingMandatory
    | MandatoryNotInLetters Char String


{-| Extracts minimum word size from a validated Puzzle.
-}
size : Puzzle -> Int
size (Puzzle p) =
    p.size


{-| Extracts the mandatory letter from a validated Puzzle.
-}
mandatory : Puzzle -> Char
mandatory (Puzzle p) =
    p.mandatory


{-| Extracts the allowed letter pool from a validated Puzzle.
-}
letters : Puzzle -> String
letters (Puzzle p) =
    p.letters


{-| Returns whether repeating letters are permitted in candidate words.
-}
repeats : Puzzle -> Bool
repeats (Puzzle p) =
    p.repeats


inSizeRange : Int -> Bool
inSizeRange s =
    s >= minWordSize && s <= maxPoolSize


isUnique : String -> Bool
isUnique str =
    let
        chars =
            String.toList str
    in
    List.length chars == Set.size (Set.fromList chars)


isLetters : String -> Bool
isLetters ls =
    inSizeRange (String.length ls)
        && String.all Char.isLower ls
        && isUnique ls


{-| Validates integer minimum word size between 4 and 9 inclusive.
-}
validateSize : Int -> Validation ValidationError Int
validateSize s =
    if inSizeRange s then
        Validation.succeed s

    else
        Validation.fail (InvalidSize ( minWordSize, maxPoolSize ) s)


validateSizeString : String -> Validation ValidationError Int
validateSizeString s =
    case String.toInt s of
        Just n ->
            validateSize n

        Nothing ->
            Validation.fail (SizeNotANumber s)


validateMandatory : Char -> Validation ValidationError Char
validateMandatory m =
    if m == ' ' then
        Validation.fail MissingMandatory

    else if Char.isLower m then
        Validation.succeed m

    else
        Validation.fail (InvalidMandatory m)


validateMandatoryInLetters : Char -> String -> Validation ValidationError ()
validateMandatoryInLetters m ls =
    if m == ' ' then
        Validation.succeed ()

    else if Char.isLower m && String.contains (String.fromChar m) ls then
        Validation.succeed ()

    else
        Validation.fail (MandatoryNotInLetters m ls)


{-| Validates that letter pool contains 4 to 9 unique lowercase letters.
-}
validateLetters : String -> Validation ValidationError String
validateLetters ls =
    if String.isEmpty ls then
        Validation.fail (InvalidLetters "empty letters")

    else if isLetters ls then
        Validation.succeed ls

    else
        Validation.fail (InvalidLetters ls)


assemble :
    Bool
    -> Validation ValidationError Int
    -> Char
    -> String
    -> Validation ValidationError Puzzle
assemble r validSize m ls =
    Validation.succeed
        (\sz md l ->
            Puzzle
                { size = sz
                , mandatory = md
                , mandString = String.fromChar md
                , mandMask = bitOf md
                , letters = l
                , repeats = r
                , poolMask = maskOf l
                }
        )
        |> Validation.andMap validSize
        |> Validation.andMap (validateMandatory m)
        |> Validation.andMap (validateLetters ls)
        |> Validation.keep (validateMandatoryInLetters m ls)


{-| Validates puzzle parameters given an integer size constraint.
-}
mkPuzzle : Bool -> Int -> Char -> String -> Validation ValidationError Puzzle
mkPuzzle r s =
    assemble r (validateSize s)


{-| Validates puzzle parameters given a string size input from a form.
-}
mkPuzzleFromString :
    Bool
    -> String
    -> Char
    -> String
    -> Validation ValidationError Puzzle
mkPuzzleFromString r s =
    assemble r (validateSizeString s)


bitOf : Char -> Int
bitOf c =
    let
        code =
            Char.toCode c - 97
    in
    if code >= 0 && code < 26 then
        Bitwise.shiftLeftBy code 1

    else
        0


maskOf : String -> Int
maskOf pool =
    String.foldl (\c mask -> Bitwise.or mask (bitOf c)) 0 pool


nineLettersWithMask : Int -> String -> Bool
nineLettersWithMask poolMask word =
    let
        check used chars =
            case chars of
                [] ->
                    True

                char :: remaining ->
                    let
                        charBit =
                            bitOf char

                        isInPool =
                            Bitwise.and charBit poolMask /= 0

                        alreadySeen =
                            Bitwise.and charBit used /= 0
                    in
                    if not isInPool || alreadySeen then
                        False

                    else
                        check (Bitwise.or used charBit) remaining
    in
    check 0 (String.toList word)


{-| Checks if word can be formed from pool without repeating any letter.
-}
nineLetters : String -> String -> Bool
nineLetters pool word =
    nineLettersWithMask (maskOf pool) word


spellingBeeWithMask : Int -> String -> Bool
spellingBeeWithMask poolMask word =
    let
        isInPool char =
            Bitwise.and (bitOf char) poolMask /= 0
    in
    String.all isInPool word


{-| Checks if word can be formed using only letters from the pool, allowing
repeats.
-}
spellingBee : String -> String -> Bool
spellingBee pool word =
    spellingBeeWithMask (maskOf pool) word


{-| Evaluates whether a candidate word satisfies all puzzle rules.
-}
accepts : Puzzle -> String -> Bool
accepts (Puzzle p) word =
    let
        len =
            String.length word
    in
    if len < p.size || (not p.repeats && len > maxPoolSize) then
        False

    else if not (String.contains p.mandString word) then
        False

    else if p.repeats then
        spellingBeeWithMask p.poolMask word

    else
        nineLettersWithMask p.poolMask word


{-| Finds all words in the length-partitioned dictionary index matching
puzzle criteria, grouped by descending length and sorted alphabetically.

Evaluates Spelling Bee queries in O(1) bitwise operations per candidate and
applies a two-tier filter for Nine-Letter Target mode.

-}
solve : Puzzle -> WordIndex -> List WordGroup
solve (Puzzle p) index =
    let
        minLen =
            p.size

        maxLen =
            if p.repeats then
                1000

            else
                min maxPoolSize (String.length p.letters)

        isMatchingWord =
            if p.repeats then
                \entry ->
                    Bitwise.and entry.mask p.poolMask
                        == entry.mask
                        && Bitwise.and entry.mask p.mandMask
                        /= 0

            else
                \entry ->
                    Bitwise.and entry.mask p.poolMask
                        == entry.mask
                        && Bitwise.and entry.mask p.mandMask
                        /= 0
                        && entry.popcount
                        == String.length entry.word

        filterBucket len entries =
            if len < minLen || len > maxLen then
                []

            else
                List.filter isMatchingWord entries
                    |> List.map .word
    in
    Dict.toList index
        |> List.filterMap
            (\( len, entries ) ->
                let
                    matchedWords =
                        filterBucket len entries
                in
                if List.isEmpty matchedWords then
                    Nothing

                else
                    Just
                        { length = len
                        , words = List.sort matchedWords
                        }
            )
        |> List.sortBy (\group -> negate group.length)


{-| Finds all matching words from a flat list of strings.
Useful for property testing and CLI parity verification.
-}
solveWords : Puzzle -> List String -> List WordGroup
solveWords puzzle rawWords =
    solve puzzle (Dictionary.fromWords rawWords)


{-| Converts domain validation errors into descriptive user feedback.
-}
errorToString : ValidationError -> String
errorToString err =
    case err of
        InvalidSize ( low, high ) actual ->
            "expected value in range ("
                ++ String.fromInt low
                ++ ", "
                ++ String.fromInt high
                ++ ") got "
                ++ String.fromInt actual

        InvalidLetters ls ->
            "expected 4-9 unique lowercase letters, got " ++ ls

        SizeNotANumber s ->
            "expected a whole number for size, got \"" ++ s ++ "\""

        InvalidMandatory c ->
            "expected lowercase letter ('a' to 'z') for mandatory, got '"
                ++ String.fromChar c
                ++ "'"

        MissingMandatory ->
            "mandatory letter is required ('a' to 'z' only)"

        MandatoryNotInLetters c ls ->
            "mandatory letter '"
                ++ String.fromChar c
                ++ "' not in letters \""
                ++ ls
                ++ "\""
