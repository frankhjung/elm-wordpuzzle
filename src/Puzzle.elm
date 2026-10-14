module Puzzle exposing
    ( Puzzle
    , ValidationError(..)
    , WordGroup
    , accepts
    , errorToString
    , letters
    , mandatory
    , mkPuzzle
    , mkPuzzleFromString
    , nineLetters
    , repeats
    , size
    , solve
    , spellingBee
    , validateLetters
    , validateSize
    )

{-| Word puzzle core domain model, validators, and bitmask solver.
Port of Haskell WordPuzzle module.
-}

import Bitwise
import Set
import Validation exposing (Validation)


{-| Opaque Puzzle configuration. The constructor is not exported.
Use mkPuzzle or mkPuzzleFromString to construct a validated Puzzle.
-}
type Puzzle
    = Puzzle
        { size : Int
        , mandatory : Char
        , letters : String
        , repeats : Bool
        , poolMask : Int
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
        && String.all Char.isLower ls
        && isUnique ls


validateSize : Int -> Validation ValidationError Int
validateSize s =
    if isSize s then
        Validation.succeed s

    else
        Validation.fail (InvalidSize ( 4, 9 ) s)


validateSizeString : String -> Validation ValidationError Int
validateSizeString s =
    case String.toInt s of
        Just n ->
            validateSize n

        Nothing ->
            Validation.fail (UnexpectedValue "size")


validateMandatory : Char -> Validation ValidationError Char
validateMandatory m =
    if Char.isLower m then
        Validation.succeed m

    else
        Validation.fail (InvalidMandatory m)


validateMandatoryInLetters : Char -> String -> Validation ValidationError ()
validateMandatoryInLetters m ls =
    if Char.isLower m && String.contains (String.fromChar m) ls then
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
                , poolMask = maskOf l
                }
        )
        |> Validation.andMap (validateSize s)
        |> Validation.andMap (validateMandatory m)
        |> Validation.andMap (validateLetters ls)
        |> Validation.keep (validateMandatoryInLetters m ls)


mkPuzzleFromString : Bool -> String -> Char -> String -> Validation ValidationError Puzzle
mkPuzzleFromString r s m ls =
    Validation.succeed
        (\sz md l ->
            Puzzle
                { size = sz
                , mandatory = md
                , letters = l
                , repeats = r
                , poolMask = maskOf l
                }
        )
        |> Validation.andMap (validateSizeString s)
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


nineLettersWithMask : Int -> String -> Bool
nineLettersWithMask poolMask word =
    let
        step c ( mask, ok ) =
            if not ok then
                ( mask, False )

            else
                let
                    bit =
                        bitOf c
                in
                if bit == 0 || Bitwise.and bit poolMask == 0 || Bitwise.and mask bit /= 0 then
                    ( mask, False )

                else
                    ( Bitwise.or mask bit, True )
    in
    Tuple.second (String.foldl step ( 0, True ) word)


nineLetters : String -> String -> Bool
nineLetters pool word =
    nineLettersWithMask (maskOf pool) word


spellingBeeWithMask : Int -> String -> Bool
spellingBeeWithMask poolMask word =
    let
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


spellingBee : String -> String -> Bool
spellingBee pool word =
    spellingBeeWithMask (maskOf pool) word


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
            String.any (\c -> c == p.mandatory) word

        matchesPool =
            if p.repeats then
                spellingBeeWithMask p.poolMask word

            else
                nineLettersWithMask p.poolMask word
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
    List.foldr
        (\word acc ->
            let
                len =
                    String.length word
            in
            case acc of
                group :: rest ->
                    if group.length == len then
                        { group | words = word :: group.words } :: rest

                    else
                        { length = len, words = [ word ] } :: acc

                [] ->
                    [ { length = len, words = [ word ] } ]
        )
        []
        words


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
