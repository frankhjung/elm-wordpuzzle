module MainTest exposing (suite)

{-| State machine and update cycle unit tests for the Main application module.
Verifies that form inputs sanitise correctly and outcomes transition strictly.
-}

import Dictionary
import Expect
import Http
import Main
import Puzzle exposing (ValidationError(..))
import Test exposing (Test, describe, test)
import View.Results as ResultsView


updateAll : List Main.Msg -> Main.Model -> Main.Model
updateAll msgs initial =
    List.foldl (\msg model -> Tuple.first (Main.update msg model)) initial msgs


suite : Test
suite =
    describe "Main Application State Machine"
        [ test "initial state loads dictionary and starts un-solved" <|
            \_ ->
                let
                    ( model, _ ) =
                        Main.init Nothing
                in
                Expect.all
                    [ \m -> Expect.equal "" m.form.mandatory
                    , \m -> Expect.equal "" m.form.otherLetters
                    , \m -> Expect.equal "4" m.form.size
                    , \m -> Expect.equal True m.form.repeats
                    , \m -> Expect.equal ResultsView.NotSolved m.outcome
                    ]
                    model
        , test "SetMandatory filters non-alpha and enforces lowercase char" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    ( updated, _ ) =
                        Main.update (Main.SetMandatory "M1!") initial
                in
                Expect.equal "m" updated.form.mandatory
        , test "SetOtherLetters forces lowercase and caps at 8 characters" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    ( updated, _ ) =
                        Main.update
                            (Main.SetOtherLetters "ABCDEFGHIJKL")
                            initial
                in
                Expect.equal "abcdefgh" updated.form.otherLetters
        , test "successful submit transitions to Solved with sorted word groups" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    solved =
                        updateAll
                            [ Main.GotDictionary
                                (Ok "mitncao\nmanic\nmaniac\ncat\n")
                            , Main.SetMandatory "m"
                            , Main.SetOtherLetters "itncao"
                            , Main.Submit
                            ]
                            initial
                in
                case solved.outcome of
                    ResultsView.Solved _ groups ->
                        let
                            allWords =
                                List.concatMap .words groups
                        in
                        Expect.all
                            [ \_ ->
                                Expect.equal True (List.member "manic" allWords)
                            , \_ ->
                                Expect.equal True
                                    (List.member "maniac" allWords)
                            ]
                            ()

                    _ ->
                        Expect.fail "Expected Solved outcome"
        , test "editing inputs after solve retains results until next submit" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    solved =
                        updateAll
                            [ Main.GotDictionary (Ok "mitncao\nmanic\n")
                            , Main.SetMandatory "m"
                            , Main.SetOtherLetters "itncao"
                            , Main.Submit
                            ]
                            initial

                    ( edited, _ ) =
                        Main.update (Main.SetOtherLetters "xyz") solved
                in
                case edited.outcome of
                    ResultsView.Solved _ _ ->
                        Expect.pass

                    _ ->
                        Expect.fail "Results should be retained while editing"
        , test "invalid submit reports accumulated validation errors" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    failed =
                        updateAll
                            [ Main.GotDictionary (Ok "valid\n")
                            , Main.SetOtherLetters "a"
                            , Main.SetSize "2"
                            , Main.Submit
                            ]
                            initial
                in
                case failed.outcome of
                    ResultsView.Invalid errs ->
                        Expect.all
                            [ \e ->
                                Expect.equal True
                                    (List.member (InvalidSize ( 4, 9 ) 2) e)
                            , \e ->
                                Expect.equal True
                                    (List.member MissingMandatory e)
                            , \e ->
                                Expect.equal True
                                    (List.member (InvalidLetters "a") e)
                            ]
                            errs

                    _ ->
                        Expect.fail "Expected Invalid outcome"
        , test "retry resets dictionary status to Loading" <|
            \_ ->
                let
                    ( initial, _ ) =
                        Main.init Nothing

                    ( failed, _ ) =
                        Main.update
                            (Main.GotDictionary (Err Http.NetworkError))
                            initial

                    ( retrying, _ ) =
                        Main.update Main.Retry failed
                in
                case retrying.dictionary of
                    Dictionary.Loading ->
                        Expect.pass

                    _ ->
                        Expect.fail "Expected dictionary status to be Loading"
        , test "initial state with flags immediately loads word list" <|
            \_ ->
                let
                    ( model, cmd ) =
                        Main.init (Just "alpha\nbravo\ncharlie\n")
                in
                case model.dictionary of
                    Dictionary.Loaded words ->
                        Expect.all
                            [ \_ ->
                                Expect.equal
                                    [ "alpha", "bravo", "charlie" ]
                                    words
                            , \_ -> Expect.equal Cmd.none cmd
                            ]
                            ()

                    _ ->
                        Expect.fail "Expected dictionary to be Loaded immediately"
        ]
