module Main exposing
    ( Flags
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
import Dictionary
import Html exposing (Html, a, div, footer, h1, header, main_, p, text)
import Html.Attributes exposing (class, href, rel, target)
import Http
import Puzzle
import View.Form as FormView
import View.Results as ResultsView


type alias Model =
    { dictionary : Dictionary.Status
    , form : FormView.Form
    , outcome : ResultsView.Outcome
    }


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
    { dictionary = Dictionary.Loading
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
            ( { initialModel
                | dictionary = Dictionary.Loaded (Dictionary.parse content)
              }
            , Cmd.none
            )

        Nothing ->
            ( initialModel
            , Dictionary.fetch GotDictionary
            )


updateForm : (FormView.Form -> FormView.Form) -> Model -> ( Model, Cmd Msg )
updateForm modify model =
    ( { model | form = modify model.form }, Cmd.none )


lowerLetters : Int -> String -> String
lowerLetters limit raw =
    String.toLower raw
        |> String.filter Char.isLower
        |> String.left limit


solveForm : FormView.Form -> Dictionary.Dictionary -> ResultsView.Outcome
solveForm form dict =
    let
        mandChar =
            String.uncons form.mandatory
                |> Maybe.map Tuple.first
                |> Maybe.withDefault ' '

        letters =
            form.mandatory ++ form.otherLetters
    in
    case Puzzle.mkPuzzleFromString form.repeats form.size mandChar letters of
        Ok puzzle ->
            ResultsView.Solved puzzle (Puzzle.solve puzzle dict)

        Err errors ->
            ResultsView.Invalid errors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDictionary (Ok content) ->
            ( { model
                | dictionary = Dictionary.Loaded (Dictionary.parse content)
              }
            , Cmd.none
            )

        GotDictionary (Err error) ->
            ( { model | dictionary = Dictionary.Failed error }
            , Cmd.none
            )

        SetMandatory raw ->
            updateForm (\f -> { f | mandatory = lowerLetters 1 raw }) model

        SetOtherLetters raw ->
            updateForm (\f -> { f | otherLetters = lowerLetters 8 raw }) model

        SetSize raw ->
            updateForm
                (\f ->
                    let
                        digits =
                            String.filter Char.isDigit raw
                    in
                    { f | size = String.left 2 digits }
                )
                model

        ToggleRepeats enabled ->
            updateForm (\f -> { f | repeats = enabled }) model

        Retry ->
            ( { model | dictionary = Dictionary.Loading }
            , Dictionary.fetch GotDictionary
            )

        Submit ->
            case model.dictionary of
                Dictionary.Loaded dict ->
                    ( { model | outcome = solveForm model.form dict }
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

                ResultsView.NotSolved ->
                    []

                ResultsView.Solved _ _ ->
                    []

        isDictLoading =
            model.dictionary == Dictionary.Loading
    in
    div [ class "app-shell" ]
        [ header [ class "app-header" ]
            [ div [ class "header-inner" ]
                [ h1 [ class "app-title" ] [ text "Word Puzzle Solver" ] ]
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
                        { dictionary = model.dictionary
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
