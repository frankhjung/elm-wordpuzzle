module Main exposing
    ( DictionaryStatus(..)
    , Flags
    , Model
    , Msg(..)
    , init
    , main
    , update
    )

{-| Single-page application entry point for the Elm Word Puzzle Solver.
Wires state management, HTTP dictionary loading, and responsive views.
-}

import Browser
import Dictionary exposing (Dictionary)
import Html exposing (Html, a, div, footer, h1, header, main_, p, text)
import Html.Attributes exposing (class, href, rel, target)
import Http
import Puzzle
import View.Form as FormView
import View.Results as ResultsView


type alias Model =
    { dictionary : DictionaryStatus
    , form : FormView.Form
    , outcome : ResultsView.Outcome
    }


type DictionaryStatus
    = Loading
    | Loaded Dictionary
    | Failed Http.Error


type Msg
    = GotDictionary (Result Http.Error String)
    | SetMandatory String
    | SetOtherLetters String
    | SetSize String
    | ToggleRepeats Bool
    | Submit
    | Retry


type alias Flags =
    Maybe String


initialModel : Model
initialModel =
    { dictionary = Loading
    , form =
        { mandatory = ""
        , otherLetters = ""
        , size = "4"
        , repeats = True
        }
    , outcome = ResultsView.NotSolved
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    case flags of
        Just content ->
            ( { initialModel | dictionary = Loaded (Dictionary.parse content) }
            , Cmd.none
            )

        Nothing ->
            ( initialModel
            , Dictionary.fetch GotDictionary
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDictionary result ->
            case result of
                Ok content ->
                    ( { model | dictionary = Loaded (Dictionary.parse content) }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | dictionary = Failed error }
                    , Cmd.none
                    )

        SetMandatory raw ->
            let
                cleaned =
                    String.toLower raw
                        |> String.filter Char.isLower
                        |> String.left 1

                currentForm =
                    model.form
            in
            ( { model | form = { currentForm | mandatory = cleaned } }
            , Cmd.none
            )

        SetOtherLetters raw ->
            let
                cleaned =
                    String.toLower raw
                        |> String.filter Char.isLower
                        |> String.left 8

                currentForm =
                    model.form
            in
            ( { model | form = { currentForm | otherLetters = cleaned } }
            , Cmd.none
            )

        SetSize raw ->
            let
                cleaned =
                    String.filter Char.isDigit raw
                        |> String.left 2

                currentForm =
                    model.form
            in
            ( { model | form = { currentForm | size = cleaned } }
            , Cmd.none
            )

        ToggleRepeats enabled ->
            let
                currentForm =
                    model.form
            in
            ( { model | form = { currentForm | repeats = enabled } }
            , Cmd.none
            )

        Retry ->
            ( { model | dictionary = Loading }
            , Dictionary.fetch GotDictionary
            )

        Submit ->
            case model.dictionary of
                Loaded dict ->
                    let
                        mandatoryChar =
                            case String.uncons model.form.mandatory of
                                Just ( c, _ ) ->
                                    c

                                Nothing ->
                                    ' '

                        fullLetters =
                            model.form.mandatory ++ model.form.otherLetters
                    in
                    case Puzzle.mkPuzzleFromString model.form.repeats model.form.size mandatoryChar fullLetters of
                        Ok puzzle ->
                            let
                                groups =
                                    Puzzle.solve puzzle dict
                            in
                            ( { model | outcome = ResultsView.Solved puzzle groups }
                            , Cmd.none
                            )

                        Err errors ->
                            ( { model | outcome = ResultsView.Invalid errors }
                            , Cmd.none
                            )

                _ ->
                    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Model -> Html Msg
view model =
    let
        activeErrors =
            case model.outcome of
                ResultsView.Invalid errs ->
                    errs

                _ ->
                    []

        isDictLoading =
            case model.dictionary of
                Loading ->
                    True

                _ ->
                    False

        dictStatus =
            case model.dictionary of
                Loading ->
                    Ok Nothing

                Loaded d ->
                    Ok (Just d)

                Failed err ->
                    Err err
    in
    div [ class "app-shell" ]
        [ header [ class "app-header" ]
            [ div [ class "header-inner" ]
                [ h1 [ class "app-title" ] [ text "Word Puzzle Solver" ]
                , p [ class "app-subtitle" ]
                    [ text "Client-side puzzle solver in Elm" ]
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "layout-container" ]
                [ div [ class "pane-form" ]
                    [ FormView.view
                        { form = model.form
                        , errors = activeErrors
                        , isLoading = isDictLoading
                        , onSetMandatory = SetMandatory
                        , onSetOtherLetters = SetOtherLetters
                        , onSetSize = SetSize
                        , onToggleRepeats = ToggleRepeats
                        , onSubmit = Submit
                        }
                    ]
                , div [ class "pane-results" ]
                    [ ResultsView.view
                        { dictionaryStatus = dictStatus
                        , outcome = model.outcome
                        , onRetry = Retry
                        }
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ p []
                [ text "Ported from the "
                , a
                    [ href "https://github.com/frankhjung/haskell-wordpuzzle"
                    , target "_blank"
                    , rel "noopener noreferrer"
                    ]
                    [ text "Haskell Word Puzzle Solver" ]
                , text " · Built with Elm 0.19.1"
                ]
            ]
        ]


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
