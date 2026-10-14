module View.Form exposing (Form, view)

{-| Accessible, responsive puzzle input form.
Provides immediate input sanitisation and field-level error indicators.
-}

import Html exposing (Html, button, div, h2, input, label, small, span, text)
import Html.Attributes exposing (attribute, autocomplete, checked, class, classList, disabled, for, id, maxlength, name, novalidate, placeholder, type_, value)
import Html.Events exposing (onCheck, onInput, onSubmit)
import Puzzle exposing (ValidationError(..))


type alias Form =
    { mandatory : String
    , otherLetters : String
    , size : String
    , repeats : Bool
    }


type alias Config msg =
    { form : Form
    , errors : List ValidationError
    , isLoading : Bool
    , onSetMandatory : String -> msg
    , onSetOtherLetters : String -> msg
    , onSetSize : String -> msg
    , onToggleRepeats : Bool -> msg
    , onSubmit : msg
    }


hasMandatoryError : List ValidationError -> Bool
hasMandatoryError errors =
    List.any
        (\e ->
            case e of
                InvalidMandatory _ ->
                    True

                MandatoryNotInLetters _ _ ->
                    True

                _ ->
                    False
        )
        errors


hasLettersError : List ValidationError -> Bool
hasLettersError errors =
    List.any
        (\e ->
            case e of
                InvalidLetters _ ->
                    True

                MandatoryNotInLetters _ _ ->
                    True

                _ ->
                    False
        )
        errors


hasSizeError : List ValidationError -> Bool
hasSizeError errors =
    List.any
        (\e ->
            case e of
                InvalidSize _ _ ->
                    True

                UnexpectedValue "size" ->
                    True

                _ ->
                    False
        )
        errors


view : Config msg -> Html msg
view config =
    let
        mandatoryError =
            hasMandatoryError config.errors

        lettersError =
            hasLettersError config.errors

        sizeError =
            hasSizeError config.errors
    in
    Html.form
        [ class "puzzle-form"
        , onSubmit config.onSubmit
        , novalidate True
        ]
        [ h2 [ class "form-title" ] [ text "Puzzle Configuration" ]
        , div [ class "form-group" ]
            [ label [ for "input-mandatory", class "form-label" ]
                [ text "Mandatory Letter"
                , span [ class "required-indicator" ] [ text " *" ]
                ]
            , input
                [ id "input-mandatory"
                , name "mandatory"
                , type_ "text"
                , classList
                    [ ( "form-input", True )
                    , ( "input-error", mandatoryError )
                    ]
                , value config.form.mandatory
                , onInput config.onSetMandatory
                , maxlength 1
                , placeholder "e.g. m"
                , autocomplete False
                , attribute "autocapitalize" "none"
                , attribute "spellcheck" "false"
                , attribute "inputmode" "text"
                , attribute "aria-required" "true"
                , attribute "aria-invalid"
                    (if mandatoryError then
                        "true"

                     else
                        "false"
                    )
                ]
                []
            , small [ class "form-hint" ]
                [ text "Single lowercase letter that must appear in every word." ]
            ]
        , div [ class "form-group" ]
            [ label [ for "input-other-letters", class "form-label" ]
                [ text "Other Letters"
                , span [ class "required-indicator" ] [ text " *" ]
                ]
            , input
                [ id "input-other-letters"
                , name "otherLetters"
                , type_ "text"
                , classList
                    [ ( "form-input", True )
                    , ( "input-error", lettersError )
                    ]
                , value config.form.otherLetters
                , onInput config.onSetOtherLetters
                , maxlength 8
                , placeholder "e.g. itncao"
                , autocomplete False
                , attribute "autocapitalize" "none"
                , attribute "spellcheck" "false"
                , attribute "inputmode" "text"
                , attribute "aria-required" "true"
                , attribute "aria-invalid"
                    (if lettersError then
                        "true"

                     else
                        "false"
                    )
                ]
                []
            , small [ class "form-hint" ]
                [ text "3 to 8 additional unique letters to complete the pool." ]
            ]
        , div [ class "form-group" ]
            [ label [ for "input-size", class "form-label" ]
                [ text "Minimum Word Size" ]
            , input
                [ id "input-size"
                , name "size"
                , type_ "number"
                , classList
                    [ ( "form-input", True )
                    , ( "input-error", sizeError )
                    ]
                , value config.form.size
                , onInput config.onSetSize
                , attribute "min" "4"
                , attribute "max" "9"
                , attribute "inputmode" "numeric"
                , attribute "aria-invalid"
                    (if sizeError then
                        "true"

                     else
                        "false"
                    )
                ]
                []
            , small [ class "form-hint" ]
                [ text "Minimum length between 4 and 9 letters (default: 4)." ]
            ]
        , div [ class "form-group-checkbox" ]
            [ label [ class "checkbox-label" ]
                [ input
                    [ id "toggle-repeats"
                    , name "repeats"
                    , type_ "checkbox"
                    , class "checkbox-input"
                    , checked config.form.repeats
                    , onCheck config.onToggleRepeats
                    ]
                    []
                , span [ class "checkbox-text" ]
                    [ text "Allow repeating letters?" ]
                ]
            , small [ class "form-hint" ]
                [ text "Permits letters to be reused without length limit (e.g. Spelling Bee)." ]
            ]
        , div [ class "form-actions" ]
            [ button
                [ id "btn-solve"
                , type_ "submit"
                , class "btn-primary"
                , disabled config.isLoading
                ]
                [ if config.isLoading then
                    span [ class "btn-loading-content" ]
                        [ span [ class "spinner" ] []
                        , text "Loading Dictionary..."
                        ]

                  else
                    text "Solve Puzzle"
                ]
            ]
        ]
