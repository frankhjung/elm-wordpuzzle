module Dictionary exposing
    ( Dictionary, IndexedWord, WordIndex, RemoteData(..), Status
    , parse, fromWords, words, wordsOfLength
    , fetch, errorToString
    )

{-| Dictionary parsing, length-partitioned bitmask indexing, and asynchronous
HTTP fetching.

Safeguards the bitmask solver by filtering only lowercase ASCII words and
pre-computing 32-bit character bitmasks.


# Types

@docs Dictionary, IndexedWord, WordIndex, RemoteData, Status


# Parsing & Indexing

@docs parse, fromWords, words, wordsOfLength


# HTTP Effects

@docs fetch, errorToString

-}

import Bitwise
import Dict exposing (Dict)
import Http


{-| Pre-computed candidate word paired with its 32-bit character set bitmask
and distinct character count.
-}
type alias IndexedWord =
    { word : String
    , mask : Int
    , popcount : Int
    }


{-| Length-partitioned dictionary index mapping word lengths to lists of
pre-computed `IndexedWord` records.
-}
type alias WordIndex =
    Dict Int (List IndexedWord)


{-| Synonym for the indexed dictionary data structure.
-}
type alias Dictionary =
    WordIndex


{-| Four-state sum type modelling the lifecycle of asynchronous remote
dictionary assets.
-}
type RemoteData error data
    = NotAsked
    | Loading
    | Failure error
    | Success data


{-| Lifecycle status of the asynchronous dictionary loader.
-}
type alias Status =
    RemoteData Http.Error WordIndex


bitOf : Char -> Int
bitOf c =
    let
        code =
            Char.toCode c - 97
    in
    if code >= 0 && code < 26 then
        Bitwise.shiftLeftBy code 1

    else
        0


{-| Calculates the 26-bit character mask for a string.
-}
maskOf : String -> Int
maskOf str =
    String.foldl (\c mask -> Bitwise.or mask (bitOf c)) 0 str


countBits : Int -> Int
countBits n =
    let
        n1 =
            n - Bitwise.and (Bitwise.shiftRightZfBy 1 n) 0x55555555

        n2 =
            Bitwise.and n1 0x33333333
                + Bitwise.and (Bitwise.shiftRightZfBy 2 n1) 0x33333333

        n3 =
            Bitwise.and (n2 + Bitwise.shiftRightZfBy 4 n2) 0x0F0F0F0F

        n4 =
            n3 + Bitwise.shiftRightZfBy 8 n3

        n5 =
            n4 + Bitwise.shiftRightZfBy 16 n4
    in
    Bitwise.and n5 0x3F


isValidWord : String -> Bool
isValidWord word =
    String.length word >= 4 && String.all Char.isLower word


indexWord : String -> IndexedWord
indexWord word =
    let
        mask =
            maskOf word
    in
    { word = word
    , mask = mask
    , popcount = countBits mask
    }


insertWord : String -> WordIndex -> WordIndex
insertWord word idx =
    let
        len =
            String.length word

        entry =
            indexWord word
    in
    Dict.update len
        (\maybeList ->
            case maybeList of
                Just list ->
                    Just (entry :: list)

                Nothing ->
                    Just [ entry ]
        )
        idx


{-| Builds a length-partitioned index from a list of words.
-}
fromWords : List String -> WordIndex
fromWords wordList =
    List.filter isValidWord wordList
        |> List.foldr insertWord Dict.empty


{-| Parses raw dictionary text into candidate words, trimming whitespace,
filtering out non-lowercase ASCII words and words shorter than 4 letters, and
indexing into a length-partitioned `WordIndex`.
-}
parse : String -> WordIndex
parse content =
    String.lines content
        |> List.map String.trim
        |> fromWords


{-| Flattens an indexed dictionary into an ordered list of words.
-}
words : WordIndex -> List String
words idx =
    Dict.values idx
        |> List.concatMap (List.map .word)


{-| Retrieves candidate words of a specific length from the index.
-}
wordsOfLength : Int -> WordIndex -> List IndexedWord
wordsOfLength len idx =
    Dict.get len idx
        |> Maybe.withDefault []


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
