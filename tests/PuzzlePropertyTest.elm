module PuzzlePropertyTest exposing (suite)

{-| Property-based fuzz tests verifying domain invariants across
arbitrary inputs and asserting parity between string solving and
length-partitioned bitmask indexing.
-}

import Dictionary
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
    Fuzz.map2
        (\n shuffled ->
            case List.take n shuffled of
                first :: rest ->
                    ( first, String.fromList (first :: rest) )

                [] ->
                    ( 'a', "abcd" )
        )
        (Fuzz.intRange 4 9)
        (Fuzz.shuffledList (String.toList "abcdefghijklmnopqrstuvwxyz"))


validWord : Fuzzer String
validWord =
    Fuzz.listOfLengthBetween 4 12 asciiLowerChar
        |> Fuzz.map String.fromList


validDictionary : Fuzzer (List String)
validDictionary =
    Fuzz.listOfLengthBetween 5 25 validWord


isStrictlyDescending : List Int -> Bool
isStrictlyDescending list =
    case list of
        a :: b :: rest ->
            a > b && isStrictlyDescending (b :: rest)

        _ ->
            True


suite : Test
suite =
    describe "Puzzle Invariants (Property Tests)"
        [ fuzz2
            validPool
            validWord
            "accepted word always contains mandatory letter"
            (\( mand, pool ) word ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        if Puzzle.accepts p word then
                            Expect.equal True
                                (String.contains (String.fromChar mand) word)

                        else
                            Expect.pass

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validWord
            "repeats-off accepted words are always a subset of repeats-on"
            (\( mand, pool ) word ->
                case
                    ( Puzzle.mkPuzzle False 4 mand pool
                    , Puzzle.mkPuzzle True 4 mand pool
                    )
                of
                    ( Ok pOff, Ok pOn ) ->
                        if Puzzle.accepts pOff word then
                            Expect.equal True (Puzzle.accepts pOn word)

                        else
                            Expect.pass

                    _ ->
                        Expect.fail "Generator produced invalid puzzle pair"
            )
        , fuzz2
            validPool
            validWord
            "repeats-off words never exceed length 9 or contain duplicates"
            (\( mand, pool ) word ->
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
                                , \w ->
                                    Expect.equal (String.length w) uniqueCount
                                ]
                                word

                        else
                            Expect.pass

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validDictionary
            "all words returned by solveWords satisfy accepts"
            (\( mand, pool ) dict ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        let
                            solvedWords =
                                Puzzle.solveWords p dict
                                    |> List.concatMap .words

                            allAccepted =
                                List.all (Puzzle.accepts p) solvedWords
                        in
                        Expect.equal True allAccepted

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validDictionary
            "word groups from solveWords are ordered by strictly descending length"
            (\( mand, pool ) dict ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        let
                            lengths =
                                Puzzle.solveWords p dict
                                    |> List.map .length
                        in
                        Expect.equal True (isStrictlyDescending lengths)

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validDictionary
            "all words in each word group match group.length"
            (\( mand, pool ) dict ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        let
                            groups =
                                Puzzle.solveWords p dict

                            validGroup g =
                                List.all
                                    (\w -> String.length w == g.length)
                                    g.words
                        in
                        Expect.equal True (List.all validGroup groups)

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validDictionary
            "solve on WordIndex produces identical output to solveWords"
            (\( mand, pool ) dict ->
                case Puzzle.mkPuzzle True 4 mand pool of
                    Ok p ->
                        let
                            fromList =
                                Puzzle.solveWords p dict

                            fromIndex =
                                Puzzle.solve p (Dictionary.fromWords dict)
                        in
                        Expect.equal fromList fromIndex

                    Err errs ->
                        Expect.fail
                            ("Generator produced invalid puzzle: "
                                ++ Debug.toString errs
                            )
            )
        , fuzz2
            validPool
            validDictionary
            "Target mode solved words are always a subset of Spelling Bee solved words"
            (\( mand, pool ) dict ->
                case
                    ( Puzzle.mkPuzzle False 4 mand pool
                    , Puzzle.mkPuzzle True 4 mand pool
                    )
                of
                    ( Ok targetP, Ok beeP ) ->
                        let
                            idx =
                                Dictionary.fromWords dict

                            targetWords =
                                Puzzle.solve targetP idx
                                    |> List.concatMap .words
                                    |> Set.fromList

                            beeWords =
                                Puzzle.solve beeP idx
                                    |> List.concatMap .words
                                    |> Set.fromList
                        in
                        Expect.equal True (Set.diff targetWords beeWords |> Set.isEmpty)

                    _ ->
                        Expect.fail "Generator produced invalid puzzle pair"
            )
        ]
