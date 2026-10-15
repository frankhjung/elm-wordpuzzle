module Dictionary exposing
    ( Dictionary, Status(..)
    , parse
    , fetch, errorToString
    )

{-| Dictionary parsing and asynchronous HTTP fetching.
Safeguards the bitmask solver by filtering only lowercase ASCII words.


# Types

@docs Dictionary, Status


# Parsing

@docs parse


# HTTP Effects

@docs fetch, errorToString

-}

import Http


{-| Candidate word list representing the loaded dictionary.
-}
type alias Dictionary =
    List String


{-| Lifecycle status of the asynchronous dictionary loader.
-}
type Status
    = Loading
    | Loaded Dictionary
    | Failed Http.Error


isValidWord : String -> Bool
isValidWord word =
    String.length word >= 4 && String.all Char.isLower word


{-| Parses raw dictionary text into candidate words, trimming whitespace
and filtering out non-lowercase ASCII words and words shorter than 4 letters.
-}
parse : String -> Dictionary
parse content =
    String.lines content
        |> List.map String.trim
        |> List.filter isValidWord


{-| Asynchronously fetches the dictionary text file over HTTP.
-}
fetch : (Result Http.Error String -> msg) -> Cmd msg
fetch toMsg =
    Http.get
        { url = "dictionary.txt"
        , expect = Http.expectString toMsg
        }


{-| Converts an HTTP failure error into a user-facing explanation.
-}
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
