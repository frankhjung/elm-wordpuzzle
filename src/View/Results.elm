module View.Results exposing (Outcome(..), view)

{-| Responsive results view displaying solution cards grouped by word length.
Mandatory letters are visually highlighted in teal and bold within word chips.
-}

import Dictionary
import Html exposing (Html, button, div, h3, li, p, span, strong, text, ul)
import Html.Attributes exposing (attribute, class, id, type_)
import Html.Events exposing (onClick)
import Html.Lazy exposing (lazy2)
import Http
import Puzzle exposing (Puzzle, ValidationError, WordGroup)


type alias Config msg =
    { dictionary : Dictionary.Status
    , outcome : Outcome
    , onRetry : msg
    }


type Outcome
    = NotSolved
    | Invalid (List ValidationError)
    | Solved Puzzle (List WordGroup)


view : Config msg -> Html msg
view config =
    div [ class "results-pane", attribute "aria-live" "polite" ]
        [ case config.dictionary of
            Dictionary.Failed httpError ->
                viewDictionaryError httpError config.onRetry

            Dictionary.Loading ->
                viewDictionaryLoading

            Dictionary.Loaded _ ->
                viewOutcome config.outcome
        ]


viewDictionaryLoading : Html msg
viewDictionaryLoading =
    div [ class "status-card status-loading" ]
        [ div [ class "spinner-large" ] []
        , h3 [ class "status-title" ] [ text "Loading Dictionary" ]
        , p [ class "status-desc" ]
            [ text
                "Downloading and indexing candidate word list in browser..."
            ]
        ]


viewDictionaryError : Http.Error -> msg -> Html msg
viewDictionaryError error onRetry =
    div [ class "alert alert-error alert-banner", attribute "role" "alert" ]
        [ div [ class "alert-icon" ] [ text "!" ]
        , div [ class "alert-body" ]
            [ h3 [ class "alert-title" ] [ text "Dictionary Failed to Load" ]
            , p [ class "alert-desc" ] [ text (Dictionary.errorToString error) ]
            ]
        , button
            [ id "btn-retry"
            , type_ "button"
            , class "btn-secondary"
            , onClick onRetry
            ]
            [ text "Retry Download" ]
        ]


viewOutcome : Outcome -> Html msg
viewOutcome outcome =
    case outcome of
        NotSolved ->
            div [ class "status-card status-empty" ]
                [ h3 [ class "status-title" ] [ text "Ready to Solve" ]
                , p [ class "status-desc" ]
                    [ text
                        ("Configure mandatory letter and allowed letters, "
                            ++ "then press Solve."
                        )
                    ]
                ]

        Invalid errors ->
            div [ class "alert alert-error", attribute "role" "alert" ]
                [ h3 [ class "alert-title" ] [ text "Validation Errors" ]
                , ul [ class "error-list" ]
                    (List.map
                        (\err -> li [] [ text (Puzzle.errorToString err) ])
                        errors
                    )
                ]

        Solved puzzle groups ->
            let
                totalCount =
                    List.sum (List.map (.words >> List.length) groups)
            in
            if totalCount == 0 then
                div [ class "status-card status-no-results" ]
                    [ h3 [ class "status-title" ] [ text "No Words Found" ]
                    , p [ class "status-desc" ]
                        [ text
                            ("No words in dictionary match the specified "
                                ++ "criteria."
                            )
                        ]
                    ]

            else
                div [ class "results-container" ]
                    [ div [ class "results-header" ]
                        [ span [ class "results-count" ]
                            [ text
                                ("Found "
                                    ++ String.fromInt totalCount
                                    ++ " words"
                                )
                            ]
                        ]
                    , lazy2 renderGroups (Puzzle.mandatory puzzle) groups
                    ]


renderGroups : Char -> List WordGroup -> Html msg
renderGroups mand groups =
    div [ class "word-groups-list" ]
        (List.map (renderWordGroup mand) groups)


renderWordGroup : Char -> WordGroup -> Html msg
renderWordGroup mand group =
    div [ class "word-group-card" ]
        [ h3 [ class "word-group-title" ]
            [ text
                (String.fromInt group.length
                    ++ "-Letter Words ("
                    ++ String.fromInt (List.length group.words)
                    ++ ")"
                )
            ]
        , div [ class "chips-container" ]
            (List.map (renderWordChip mand) group.words)
        ]


renderWordChip : Char -> String -> Html msg
renderWordChip mand word =
    let
        m =
            String.fromChar mand
    in
    span [ class "word-chip" ]
        (String.split m word
            |> List.map text
            |> List.intersperse
                (strong [ class "char-mandatory" ] [ text m ])
        )
