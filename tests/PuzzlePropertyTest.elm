module PuzzlePropertyTest exposing (suite)

{-| Property-based fuzz tests verifying domain invariants across arbitrary inputs.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Puzzle
import Set
import Test exposing (Test, describe, fuzz2)


asciiLowerChar : Fuzzer Char
asciiLowerChar =
    Fuzz.intRange 97 122
        |> Fuzz.map Char.fromCode


validPool : Fuzzer ( Char, String )
validPool =
    Fuzz.listOfLengthBetween 4 9 asciiLowerChar
        |> Fuzz.map
            (\chars ->
                let
                    unique =
                        Set.toList (Set.fromList chars)

                    filled =
                        if List.length unique < 4 then
                            unique ++ [ 'a', 'b', 'c', 'd' ] |> Set.fromList |> Set.toList

                        else
                            unique

                    pool =
                        List.take 9 filled
                in
                case pool of
                    first :: _ ->
                        ( first, String.fromList pool )

                    [] ->
                        ( 'a', "abcd" )
            )


validWord : Fuzzer String
validWord =
    Fuzz.listOfLengthBetween 4 12 asciiLowerChar
        |> Fuzz.map String.fromList


suite : Test
suite =
    describe "Puzzle Invariants (Property Tests)"
        [ fuzz2 validPool validWord "accepted word always contains mandatory letter" <|
            \( mand, pool ) word ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        if Puzzle.accepts p word then
                            Expect.equal True (String.contains (String.fromChar mand) word)

                        else
                            Expect.pass

                    Err _ ->
                        Expect.pass
        , fuzz2 validPool validWord "repeats-off accepted words are always a subset of repeats-on" <|
            \( mand, pool ) word ->
                case ( Puzzle.mkPuzzle False 4 mand pool, Puzzle.mkPuzzle True 4 mand pool ) of
                    ( Ok pOff, Ok pOn ) ->
                        if Puzzle.accepts pOff word then
                            Expect.equal True (Puzzle.accepts pOn word)

                        else
                            Expect.pass

                    _ ->
                        Expect.pass
        , fuzz2 validPool validWord "repeats-off accepted words never exceed length 9 or contain duplicates" <|
            \( mand, pool ) word ->
                case Puzzle.mkPuzzle False 4 mand pool of
                    Ok pOff ->
                        if Puzzle.accepts pOff word then
                            let
                                chars =
                                    String.toList word

                                uniqueCount =
                                    Set.size (Set.fromList chars)
                            in
                            Expect.all
                                [ \w -> Expect.atMost 9 (String.length w)
                                , \w -> Expect.equal (String.length w) uniqueCount
                                ]
                                word

                        else
                            Expect.pass

                    Err _ ->
                        Expect.pass
        ]
