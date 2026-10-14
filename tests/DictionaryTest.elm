module DictionaryTest exposing (suite)

{-| Dictionary parser verification.
Tests handling of CRLF, whitespace, capitalised words, and short words.
-}

import Dictionary
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Dictionary Parser"
        [ test "filters out words shorter than 4 characters" <|
            \_ ->
                Dictionary.parse "cat\nbird\nfish\na\nto"
                    |> Expect.equal [ "bird", "fish" ]
        , test "filters out uppercase and punctuation" <|
            \_ ->
                Dictionary.parse "word\nApple\nnon-word\n1234\nvalid"
                    |> Expect.equal [ "word", "valid" ]
        , test "handles CRLF line endings and trims whitespace" <|
            \_ ->
                Dictionary.parse "  alpha  \u{000D}\n  bravo  \u{000D}\ncharlie\u{000D}\n"
                    |> Expect.equal [ "alpha", "bravo", "charlie" ]
        , test "drops non-ascii characters to protect 26-bit solver" <|
            \_ ->
                Dictionary.parse "cliché\nresume\nrésumé\nnaïve\nnaive"
                    |> Expect.equal [ "resume", "naive" ]
        ]
