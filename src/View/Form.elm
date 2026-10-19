module View.Form exposing
    ( Form, initialForm
    , view
    )

{-| Accessible, responsive puzzle input form.
Provides immediate input sanitisation and field-level error indicators.


# Types

@docs Form, initialForm


# View

@docs view

-}

import Html
    exposing
        ( Html
        , button
        , div
        , fieldset
        , h2
        , input
        , label
        , legend
        , small
        , span
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , autocomplete
        , checked
        , class
        , classList
        , disabled
        , for
        , id
        , maxlength
        , name
        , novalidate
        , placeholder
        , type_
        , value
        )
import Html.Events exposing (onCheck, onInput, onSubmit)
import Puzzle exposing (ValidationError(..))


{-| Form inputs holding raw user inputs before validation.
-}
type alias Form =
    { mandatory : String
    , otherLetters : String
    , size : String
    , repeats : Bool
    }


{-| Default initial state for form inputs.

Pre-populates size to `"4"` and repeats to `True` (Spelling Bee mode).

Examples:

    initialForm.size == "4"

    initialForm.repeats == True

-}
initialForm : Form
initialForm =
    { mandatory = ""
    , otherLetters = ""
    , size = "4"
    , repeats = True
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


{-| Identifies whether a validation error pertains to the mandatory letter.

Examples:

    affectsMandatory MissingMandatory == True

    affectsMandatory (InvalidLetters "abc") == False

-}
affectsMandatory : ValidationError -> Bool
affectsMandatory err =
    case err of
        InvalidMandatory _ ->
            True

        MissingMandatory ->
            True

        MandatoryNotInLetters _ _ ->
            True

        InvalidSize _ _ ->
            False

        InvalidLetters _ ->
            False

        SizeNotANumber _ ->
            False


{-| Identifies whether a validation error pertains to the letter pool field.

Examples:

    affectsLetters (InvalidLetters "abc") == True

    affectsLetters MissingMandatory == False

-}
affectsLetters : ValidationError -> Bool
affectsLetters err =
    case err of
        InvalidLetters _ ->
            True

        MandatoryNotInLetters _ _ ->
            True

        InvalidSize _ _ ->
            False

        SizeNotANumber _ ->
            False

        InvalidMandatory _ ->
            False

        MissingMandatory ->
            False


{-| Identifies whether a validation error pertains to the word size field.

Examples:

    affectsSize (InvalidSize ( 4, 9 ) 2) == True

    affectsSize (SizeNotANumber "abc") == True

    affectsSize MissingMandatory == False

-}
affectsSize : ValidationError -> Bool
affectsSize err =
    case err of
        InvalidSize _ _ ->
            True

        SizeNotANumber _ ->
            True

        InvalidLetters _ ->
            False

        InvalidMandatory _ ->
            False

        MissingMandatory ->
            False

        MandatoryNotInLetters _ _ ->
            False


{-| Renders an accessible form input control group.

Includes form label, optional required asterisk indicator, input element with
dynamic error styling, ARIA validation attributes, and instructional hint text.

-}
viewField :
    { id : String
    , label : String
    , hint : String
    , required : Bool
    , invalid : Bool
    }
    -> List (Html.Attribute msg)
    -> Html msg
viewField fieldConfig attrs =
    let
        labelContent =
            if fieldConfig.required then
                [ text fieldConfig.label
                , span [ class "required-indicator" ] [ text " *" ]
                ]

            else
                [ text fieldConfig.label ]

        ariaInvalid =
            if fieldConfig.invalid then
                "true"

            else
                "false"
    in
    div [ class "form-group" ]
        [ label [ for fieldConfig.id, class "form-label" ] labelContent
        , input
            ([ id fieldConfig.id
             , classList
                [ ( "form-input", True )
                , ( "input-error", fieldConfig.invalid )
                ]
             , attribute "aria-label" fieldConfig.label
             , attribute "aria-invalid" ariaInvalid
             ]
                ++ attrs
            )
            []
        , small [ class "form-hint" ] [ text fieldConfig.hint ]
        ]


{-| Renders the puzzle input form with field-level validation indicators and
game mode presets.

Presents inputs for mandatory letter, pool letters, minimum word length, and the
repeat letters checkbox, with loading state feedback during dictionary fetch.

-}
view : Config msg -> Html msg
view config =
    Html.form
        [ class "puzzle-form"
        , onSubmit config.onSubmit
        , novalidate True
        ]
        [ h2 [ class "form-title" ] [ text "Puzzle Input" ]
        , fieldset
            [ class "form-fieldset"
            , attribute "role" "group"
            , attribute "aria-label" "Puzzle constraints"
            ]
            [ legend [ class "visually-hidden" ] [ text "Letter Constraints" ]
            , div [ class "form-row" ]
                [ viewField
                    { id = "input-mandatory"
                    , label = "Mandatory Letter"
                    , hint = "Single lowercase letter ('a' to 'z')."
                    , required = True
                    , invalid = List.any affectsMandatory config.errors
                    }
                    [ name "mandatory"
                    , type_ "text"
                    , value config.form.mandatory
                    , onInput config.onSetMandatory
                    , maxlength 1
                    , placeholder "e.g. c"
                    , autocomplete False
                    , attribute "autocapitalize" "none"
                    , attribute "spellcheck" "false"
                    , attribute "inputmode" "text"
                    , attribute "aria-required" "true"
                    ]
                , viewField
                    { id = "input-other-letters"
                    , label = "Other Letters"
                    , hint =
                        "3 to 8 additional unique letters to complete pool."
                    , required = True
                    , invalid = List.any affectsLetters config.errors
                    }
                    [ name "otherLetters"
                    , type_ "text"
                    , value config.form.otherLetters
                    , onInput config.onSetOtherLetters
                    , maxlength 8
                    , placeholder "e.g. adevrsoi"
                    , autocomplete False
                    , attribute "autocapitalize" "none"
                    , attribute "spellcheck" "false"
                    , attribute "inputmode" "text"
                    , attribute "aria-required" "true"
                    ]
                , viewField
                    { id = "input-size"
                    , label = "Minimum Word Size"
                    , hint = "Length between 4 and 9."
                    , required = False
                    , invalid = List.any affectsSize config.errors
                    }
                    [ name "size"
                    , type_ "number"
                    , value config.form.size
                    , onInput config.onSetSize
                    , attribute "min" "4"
                    , attribute "max" "9"
                    , attribute "inputmode" "numeric"
                    ]
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
                    [ text
                        ("Permits letters to be reused without length limit "
                            ++ "(e.g. Spelling Bee)."
                        )
                    ]
                ]
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
