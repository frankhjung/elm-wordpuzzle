module Dictionary exposing
    ( Dictionary
    , errorToString
    , fetch
    , parse
    )

{-| Dictionary parsing and asynchronous HTTP fetching.
Safeguards the bitmask solver by filtering only lowercase ASCII words.
-}

import Http


type alias Dictionary =
    List String


isValidWord : String -> Bool
isValidWord word =
    String.length word >= 4 && String.all Char.isLower word


parse : String -> Dictionary
parse content =
    String.lines content
        |> List.filterMap
            (\line ->
                let
                    word =
                        String.trim line
                in
                if isValidWord word then
                    Just word

                else
                    Nothing
            )


fetch : (Result Http.Error String -> msg) -> Cmd msg
fetch toMsg =
    Http.get
        { url = "dictionary.txt"
        , expect = Http.expectString toMsg
        }


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Invalid dictionary URL: " ++ url

        Http.Timeout ->
            "Network request timed out while loading dictionary."

        Http.NetworkError ->
            "Network connection failed while loading dictionary."

        Http.BadStatus code ->
            "Failed to load dictionary (HTTP " ++ String.fromInt code ++ ")."

        Http.BadBody message ->
            "Corrupt dictionary payload: " ++ message
