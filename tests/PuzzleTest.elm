module PuzzleTest exposing (suite)

{-| Direct port of the Haskell TestSpec.hs suite (21 test cases).
Asserts exact semantic parity between Elm and Haskell implementations.
-}

import Expect
import Puzzle exposing (ValidationError(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Puzzle Test Suite (Haskell TestSpec Port)"
        [ describe "validateSize"
            [ test "too small (0)" <|
                \_ ->
                    Puzzle.validateSize 0
                        |> Expect.equal (Err [ InvalidSize ( 4, 9 ) 0 ])
            , test "just below minimum (3)" <|
                \_ ->
                    Puzzle.validateSize 3
                        |> Expect.equal (Err [ InvalidSize ( 4, 9 ) 3 ])
            , test "too large (10)" <|
                \_ ->
                    Puzzle.validateSize 10
                        |> Expect.equal (Err [ InvalidSize ( 4, 9 ) 10 ])
            , test "size in range (4)" <|
                \_ ->
                    Puzzle.validateSize 4
                        |> Expect.equal (Ok 4)
            ]
        , describe "validateLetters"
            [ test "fewer than 4 letters" <|
                \_ ->
                    Puzzle.validateLetters "abc"
                        |> Expect.equal (Err [ InvalidLetters "abc" ])
            , test "4 lowercase letters (lower bound)" <|
                \_ ->
                    Puzzle.validateLetters "abcd"
                        |> Expect.equal (Ok "abcd")
            , test "mid-range lowercase letters" <|
                \_ ->
                    Puzzle.validateLetters "abcdefg"
                        |> Expect.equal (Ok "abcdefg")
            , test "9 lowercase letters (upper bound)" <|
                \_ ->
                    Puzzle.validateLetters "abcdefghi"
                        |> Expect.equal (Ok "abcdefghi")
            , test "mixed case letters" <|
                \_ ->
                    Puzzle.validateLetters "abcdeFghi"
                        |> Expect.equal (Err [ InvalidLetters "abcdeFghi" ])
            , test "duplicate characters" <|
                \_ ->
                    Puzzle.validateLetters "abca"
                        |> Expect.equal (Err [ InvalidLetters "abca" ])
            , test "too many letters" <|
                \_ ->
                    Puzzle.validateLetters "abcdefghij"
                        |> Expect.equal (Err [ InvalidLetters "abcdefghij" ])
            ]
        , describe "mkPuzzle"
            [ test "valid inputs" <|
                \_ ->
                    case Puzzle.mkPuzzle False 4 'a' "abcd" of
                        Ok p ->
                            Expect.all
                                [ \puz -> Expect.equal 4 (Puzzle.size puz)
                                , \puz -> Expect.equal 'a' (Puzzle.mandatory puz)
                                , \puz -> Expect.equal "abcd" (Puzzle.letters puz)
                                , \puz -> Expect.equal False (Puzzle.repeats puz)
                                ]
                                p

                        Err errs ->
                            Expect.fail ("Expected success, got: " ++ Debug.toString errs)
            , test "invalid size" <|
                \_ ->
                    Puzzle.mkPuzzle False 2 'a' "abcd"
                        |> Expect.equal (Err [ InvalidSize ( 4, 9 ) 2 ])
            , test "invalid letters" <|
                \_ ->
                    Puzzle.mkPuzzle False 4 'A' "AB"
                        |> Expect.equal
                            (Err
                                [ InvalidMandatory 'A'
                                , InvalidLetters "AB"
                                , MandatoryNotInLetters 'A' "AB"
                                ]
                            )
            , test "empty letters" <|
                \_ ->
                    Puzzle.mkPuzzle False 4 'a' ""
                        |> Expect.equal
                            (Err
                                [ InvalidLetters "empty letters"
                                , MandatoryNotInLetters 'a' ""
                                ]
                            )
            , test "multiple errors accumulated" <|
                \_ ->
                    Puzzle.mkPuzzle False 2 'B' "AB"
                        |> Expect.equal
                            (Err
                                [ InvalidSize ( 4, 9 ) 2
                                , InvalidMandatory 'B'
                                , InvalidLetters "AB"
                                , MandatoryNotInLetters 'B' "AB"
                                ]
                            )
            , test "mandatory not lowercase" <|
                \_ ->
                    Puzzle.mkPuzzle False 4 'A' "abcd"
                        |> Expect.equal
                            (Err
                                [ InvalidMandatory 'A'
                                , MandatoryNotInLetters 'A' "abcd"
                                ]
                            )
            , test "mandatory not in letters" <|
                \_ ->
                    Puzzle.mkPuzzle False 4 'e' "abcd"
                        |> Expect.equal (Err [ MandatoryNotInLetters 'e' "abcd" ])
            ]
        , describe "nineLetters"
            [ test "word contains valid characters" <|
                \_ ->
                    Puzzle.nineLetters "abcdef" "abcdef"
                        |> Expect.equal True
            , test "word contains valid subset" <|
                \_ ->
                    Puzzle.nineLetters "abcdef" "fedc"
                        |> Expect.equal True
            , test "word has invalid characters" <|
                \_ ->
                    Puzzle.nineLetters "abcdef" "zapd"
                        |> Expect.equal False
            , test "word has invalid frequency" <|
                \_ ->
                    Puzzle.nineLetters "abcdef" "abadefc"
                        |> Expect.equal False
            ]
        , describe "spellingBee"
            [ test "word contains valid characters" <|
                \_ ->
                    Puzzle.spellingBee "barfo" "barfoo"
                        |> Expect.equal True
            , test "word has invalid characters" <|
                \_ ->
                    Puzzle.spellingBee "barfo" "bartez"
                        |> Expect.equal False
            ]
        , describe "solver length check"
            [ test "repeats allowed permits long words" <|
                \_ ->
                    case Puzzle.mkPuzzle True 4 'a' "abcd" of
                        Ok p ->
                            Puzzle.accepts p "aaaaaaaa"
                                |> Expect.equal True

                        Err _ ->
                            Expect.fail "Setup failed"
            , test "repeats forbidden rejects words longer than 9" <|
                \_ ->
                    case Puzzle.mkPuzzle False 4 'a' "abcdefghi" of
                        Ok p ->
                            Puzzle.accepts p "abcdefghij"
                                |> Expect.equal False

                        Err _ ->
                            Expect.fail "Setup failed"
            ]
        , describe "solve"
            [ test "filters words in nine letters mode" <|
                \_ ->
                    case Puzzle.mkPuzzle False 4 'a' "abcd" of
                        Ok p ->
                            let
                                words =
                                    [ "abcd", "bcde", "aabc", "aaaa", "abcde" ]

                                groups =
                                    Puzzle.solve p words
                            in
                            Expect.equal [ { length = 4, words = [ "abcd" ] } ] groups

                        Err _ ->
                            Expect.fail "Setup failed"
            , test "filters words in spelling bee mode" <|
                \_ ->
                    case Puzzle.mkPuzzle True 4 'a' "abcd" of
                        Ok p ->
                            let
                                words =
                                    [ "abcd", "bcde", "aabc", "aaaa", "abcde" ]

                                groups =
                                    Puzzle.solve p words
                            in
                            Expect.equal [ { length = 4, words = [ "aaaa", "aabc", "abcd" ] } ] groups

                        Err _ ->
                            Expect.fail "Setup failed"
            ]
        ]
