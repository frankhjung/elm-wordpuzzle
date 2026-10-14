module Puzzle exposing
    ( Puzzle
    , ValidationError(..)
    , WordGroup
    , accepts
    , errorToString
    , letters
    , mandatory
    , mkPuzzle
    , nineLetters
    , repeats
    , size
    , solve
    , spellingBee
    , validateLetters
    , validateMandatory
    , validateMandatoryInLetters
    , validateSize
    )

{-| Word puzzle core domain model, validators, and bitmask solver.
Port of Haskell WordPuzzle module.
-}

import Bitwise
import Set
import Validation exposing (Validation)


{-| Opaque Puzzle configuration. The constructor is not exported.
Use mkPuzzle to construct a validated Puzzle.
-}
type Puzzle
    = Puzzle
        { size : Int
        , mandatory : Char
        , letters : String
        , repeats : Bool
        }


type alias WordGroup =
    { length : Int
    , words : List String
    }


type ValidationError
    = InvalidSize ( Int, Int ) Int
    | InvalidLetters String
    | UnexpectedValue String
    | InvalidMandatory Char
    | MandatoryNotInLetters Char String


size : Puzzle -> Int
size (Puzzle p) =
    p.size


mandatory : Puzzle -> Char
mandatory (Puzzle p) =
    p.mandatory


letters : Puzzle -> String
letters (Puzzle p) =
    p.letters


repeats : Puzzle -> Bool
repeats (Puzzle p) =
    p.repeats


isAsciiLower : Char -> Bool
isAsciiLower c =
    c >= 'a' && c <= 'z'


isSize : Int -> Bool
isSize s =
    s >= 4 && s <= 9


isUnique : String -> Bool
isUnique str =
    let
        chars =
            String.toList str
    in
    List.length chars == Set.size (Set.fromList chars)


isLetters : String -> Bool
isLetters ls =
    let
        n =
            String.length ls
    in
    (n >= 4 && n <= 9)
        && String.all isAsciiLower ls
        && isUnique ls


validateSize : Int -> Validation ValidationError Int
validateSize s =
    if isSize s then
        Validation.succeed s

    else
        Validation.fail (InvalidSize ( 4, 9 ) s)


validateMandatory : Char -> Validation ValidationError Char
validateMandatory m =
    if isAsciiLower m then
        Validation.succeed m

    else
        Validation.fail (InvalidMandatory m)


validateMandatoryInLetters : Char -> String -> Validation ValidationError ()
validateMandatoryInLetters m ls =
    if isAsciiLower m && String.contains (String.fromChar m) ls then
        Validation.succeed ()

    else
        Validation.fail (MandatoryNotInLetters m ls)


validateLetters : String -> Validation ValidationError String
validateLetters ls =
    if String.isEmpty ls then
        Validation.fail (InvalidLetters "empty letters")

    else if isLetters ls then
        Validation.succeed ls

    else
        Validation.fail (InvalidLetters ls)


mkPuzzle : Bool -> Int -> Char -> String -> Validation ValidationError Puzzle
mkPuzzle r s m ls =
    Validation.succeed
        (\sz md l ->
            Puzzle
                { size = sz
                , mandatory = md
                , letters = l
                , repeats = r
                }
        )
        |> Validation.andMap (validateSize s)
        |> Validation.andMap (validateMandatory m)
        |> Validation.andMap (validateLetters ls)
        |> Validation.keep (validateMandatoryInLetters m ls)


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


nineLetters : String -> String -> Bool
nineLetters pool word =
    let
        poolMask =
            maskOf pool

        step c ( mask, ok ) =
            if not ok then
                ( mask, False )

            else
                let
                    bit =
                        bitOf c
                in
                if bit == 0 || Bitwise.and bit poolMask == 0 then
                    ( mask, False )

                else if Bitwise.and mask bit /= 0 then
                    ( mask, False )

                else
                    ( Bitwise.or mask bit, True )
    in
    Tuple.second (String.foldl step ( 0, True ) word)


spellingBee : String -> String -> Bool
spellingBee pool word =
    let
        poolMask =
            maskOf pool

        step c ok =
            if not ok then
                False

            else
                let
                    bit =
                        bitOf c
                in
                bit /= 0 && Bitwise.and bit poolMask /= 0
    in
    String.foldl step True word


accepts : Puzzle -> String -> Bool
accepts (Puzzle p) word =
    let
        len =
            String.length word

        validLength =
            if p.repeats then
                len >= p.size

            else
                len >= p.size && len <= 9

        hasMandatory =
            String.contains (String.fromChar p.mandatory) word

        matchesPool =
            if p.repeats then
                spellingBee p.letters word

            else
                nineLetters p.letters word
    in
    validLength && hasMandatory && matchesPool


solve : Puzzle -> List String -> List WordGroup
solve puzzle dictionary =
    let
        matchingWords =
            List.filter (accepts puzzle) dictionary
                |> List.sortWith
                    (\a b ->
                        let
                            cmpLen =
                                compare (String.length b) (String.length a)
                        in
                        if cmpLen /= EQ then
                            cmpLen

                        else
                            compare a b
                    )
    in
    groupWords matchingWords


groupWords : List String -> List WordGroup
groupWords words =
    case words of
        [] ->
            []

        first :: rest ->
            let
                len =
                    String.length first

                ( sameLen, otherLens ) =
                    spanHelper (\w -> String.length w == len) [] rest
            in
            { length = len, words = first :: sameLen } :: groupWords otherLens


spanHelper : (a -> Bool) -> List a -> List a -> ( List a, List a )
spanHelper predicate acc list =
    case list of
        [] ->
            ( List.reverse acc, [] )

        x :: xs ->
            if predicate x then
                spanHelper predicate (x :: acc) xs

            else
                ( List.reverse acc, list )


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

        UnexpectedValue xs ->
            "unexpected value " ++ xs ++ " for parameter"

        InvalidMandatory c ->
            "expected lowercase letter for mandatory, got '"
                ++ String.fromChar c
                ++ "'"

        MandatoryNotInLetters c ls ->
            "mandatory letter '"
                ++ String.fromChar c
                ++ "' not in letters \""
                ++ ls
                ++ "\""
