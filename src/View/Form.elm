module View.Form exposing (Form, view)

{-| Accessible, responsive puzzle input form.
Provides immediate input sanitisation and field-level error indicators.
-}

import Html exposing (Html, button, div, h2, input, label, small, span, text)
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

                InvalidSize _ _ ->
                    False

                SizeNotANumber _ ->
                    False

                InvalidMandatory _ ->
                    False

                MissingMandatory ->
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
        )
        errors


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
    div [ class "form-group" ]
        [ label [ for fieldConfig.id, class "form-label" ]
            (text fieldConfig.label
                :: (if fieldConfig.required then
                        [ span [ class "required-indicator" ] [ text " *" ] ]

                    else
                        []
                   )
            )
        , input
            ([ id fieldConfig.id
             , classList
                [ ( "form-input", True )
                , ( "input-error", fieldConfig.invalid )
                ]
             , attribute "aria-invalid"
                (if fieldConfig.invalid then
                    "true"

                 else
                    "false"
                )
             ]
                ++ attrs
            )
            []
        , small [ class "form-hint" ] [ text fieldConfig.hint ]
        ]


view : Config msg -> Html msg
view config =
    Html.form
        [ class "puzzle-form"
        , onSubmit config.onSubmit
        , novalidate True
        ]
        [ h2 [ class "form-title" ] [ text "Puzzle Input" ]
        , div [ class "form-row" ]
            [ viewField
                { id = "input-mandatory"
                , label = "Mandatory Letter"
                , hint = "Single lowercase letter ('a' to 'z')."
                , required = True
                , invalid = hasMandatoryError config.errors
                }
                [ name "mandatory"
                , type_ "text"
                , value config.form.mandatory
                , onInput config.onSetMandatory
                , maxlength 1
                , placeholder "e.g. m"
                , autocomplete False
                , attribute "autocapitalize" "none"
                , attribute "spellcheck" "false"
                , attribute "inputmode" "text"
                , attribute "aria-required" "true"
                ]
            , viewField
                { id = "input-other-letters"
                , label = "Other Letters"
                , hint = "3 to 8 additional unique letters to complete pool."
                , required = True
                , invalid = hasLettersError config.errors
                }
                [ name "otherLetters"
                , type_ "text"
                , value config.form.otherLetters
                , onInput config.onSetOtherLetters
                , maxlength 8
                , placeholder "e.g. itncao"
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
                , invalid = hasSizeError config.errors
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
