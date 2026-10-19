module View.Results exposing
    ( Outcome(..)
    , view
    )

{-| Responsive results view displaying solution cards grouped by word length.
Mandatory letters are visually highlighted in teal and bold within word chips.


# Types

@docs Outcome


# View

@docs view

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


{-| Solver outcome state representing the current display status.
-}
type Outcome
    = NotSolved
    | Invalid (List ValidationError)
    | Solved Puzzle (List WordGroup)


{-| Renders the dictionary status or solved word groups.

Dispatches between dictionary loading states and solver outcome states.

-}
view : Config msg -> Html msg
view config =
    div [ class "results-pane", attribute "aria-live" "polite" ]
        [ case config.dictionary of
            Dictionary.NotAsked ->
                viewDictionaryNotAsked

            Dictionary.Loading ->
                viewDictionaryLoading

            Dictionary.Failure httpError ->
                viewDictionaryError httpError config.onRetry

            Dictionary.Success _ ->
                viewOutcome config.outcome
        ]


{-| Renders status placeholder card before dictionary loading has commenced.
-}
viewDictionaryNotAsked : Html msg
viewDictionaryNotAsked =
    div [ class "status-card status-empty" ]
        [ h3 [ class "status-title" ] [ text "Dictionary Ready" ]
        , p [ class "status-desc" ]
            [ text "Dictionary will load upon initialization." ]
        ]


{-| Renders an animated loading indicator card while downloading dictionary.
-}
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


{-| Renders an error alert banner with a retry action button.
-}
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


{-| Renders solver outcome states: instructions, errors, or matched words.
-}
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
                    List.foldl (\g acc -> acc + List.length g.words) 0 groups
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


{-| Renders the list of word group cards for all matched word lengths.
-}
renderGroups : Char -> List WordGroup -> Html msg
renderGroups mand groups =
    let
        mandStr =
            String.fromChar mand
    in
    div [ class "word-groups-list" ]
        (List.map (viewWordGroupCard mandStr) groups)


{-| Lazily evaluates and renders an individual word group card.
-}
viewWordGroupCard : String -> WordGroup -> Html msg
viewWordGroupCard mandStr group =
    lazy2 renderWordGroup mandStr group


{-| Renders a card for a word length group containing word chip badges.
-}
renderWordGroup : String -> WordGroup -> Html msg
renderWordGroup mandStr group =
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
            (List.map (renderWordChip mandStr) group.words)
        ]


{-| Renders a word chip badge, highlighting mandatory letters in bold teal.
-}
renderWordChip : String -> String -> Html msg
renderWordChip mandStr word =
    span [ class "word-chip" ]
        (String.split mandStr word
            |> List.map text
            |> List.intersperse
                (strong [ class "char-mandatory" ] [ text mandStr ])
        )
