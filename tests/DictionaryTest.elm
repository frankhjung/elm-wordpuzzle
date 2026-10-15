module DictionaryTest exposing (suite)

{-| Dictionary parser and indexer verification.
Tests handling of CRLF, whitespace, capitalised words, short words, and
length-partitioned indexing.
-}

import Dictionary
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Dictionary Parser & Indexer"
        [ test "filters out words shorter than 4 characters" <|
            \_ ->
                Dictionary.parse "cat\nbird\nfish\na\nto"
                    |> Dictionary.words
                    |> Expect.equal [ "bird", "fish" ]
        , test "filters out uppercase and punctuation" <|
            \_ ->
                Dictionary.parse "word\nApple\nnon-word\n1234\nvalid"
                    |> Dictionary.words
                    |> Expect.equal [ "word", "valid" ]
        , test "handles CRLF line endings and trims whitespace" <|
            \_ ->
                Dictionary.parse
                    "  alpha  \u{000D}\n  bravo  \u{000D}\ncharlie\u{000D}\n"
                    |> Dictionary.words
                    |> Expect.equal [ "alpha", "bravo", "charlie" ]
        , test "drops non-ascii characters to protect 26-bit solver" <|
            \_ ->
                Dictionary.parse "cliché\nresume\nrésumé\nnaïve\nnaive"
                    |> Dictionary.words
                    |> Expect.equal [ "naive", "resume" ]
        , test "correctly partitions words by length in WordIndex" <|
            \_ ->
                let
                    idx =
                        Dictionary.parse "four\nfive5\nfives\nsixsix"

                    fourLetters =
                        Dictionary.wordsOfLength 4 idx
                            |> List.map .word

                    fiveLetters =
                        Dictionary.wordsOfLength 5 idx
                            |> List.map .word
                in
                Expect.all
                    [ \_ -> Expect.equal [ "four" ] fourLetters
                    , \_ -> Expect.equal [ "fives" ] fiveLetters
                    ]
                    ()
        ]
