port module ParityWorker exposing (main)

{-| Headless Elm worker for automated parity testing against Haskell binary.
-}

import Dictionary
import Puzzle


port toNode : List String -> Cmd msg


type alias Flags =
    { dictionary : String
    , size : Int
    , mandatory : String
    , letters : String
    , repeats : Bool
    }


type alias Model =
    ()


type alias Msg =
    ()


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        dict =
            Dictionary.parse flags.dictionary

        mandChar =
            case String.uncons flags.mandatory of
                Just ( c, _ ) ->
                    c

                Nothing ->
                    ' '

        cmd =
            case Puzzle.mkPuzzle flags.repeats flags.size mandChar flags.letters of
                Ok puzzle ->
                    let
                        groups =
                            Puzzle.solve puzzle dict

                        words =
                            List.concatMap .words groups
                    in
                    toNode words

                Err _ ->
                    toNode []
    in
    ( (), cmd )


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }
