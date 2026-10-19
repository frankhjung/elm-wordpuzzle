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


{-| Maps a lowercase ASCII character ('a' to 'z') to a single-bit mask.

Returns 0 for non-lowercase ASCII characters or whitespace.

Examples:

    bitOf 'a' == 1

    bitOf 'c' == 4

    bitOf ' ' == 0

-}
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


{-| Calculates the cumulative 26-bit character set bitmask for a string.

Folds across each character in the string, bitwise OR-ing its corresponding
bit. Characters outside 'a' to 'z' contribute no set bits.

Examples:

    maskOf "cat" == Bitwise.or (bitOf 'c') (Bitwise.or (bitOf 'a') (bitOf 't'))

    maskOf "" == 0

-}
maskOf : String -> Int
maskOf str =
    String.foldl (\c mask -> Bitwise.or mask (bitOf c)) 0 str


{-| Counts how many bits are set in a 32-bit integer.

This is a classic parallel-popcount routine (sometimes called a "Hamming
weight" calculation). It works by repeatedly folding adjacent bit pairs, then
nibbles, then bytes, and finally the full 32-bit word into a total count. The
result is used to determine how many distinct characters are present in a word's
bitmask without iterating over every bit individually.

Examples:

    countBits 0 == 0
    countBits 0b10100101 == 4

-}
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


{-| Determines whether a candidate word satisfies dictionary criteria.

A valid candidate word must contain at least 4 characters and consist solely of
lowercase ASCII alphabetical characters.

Examples:

    isValidWord "word" == True

    isValidWord "cat" == False

    isValidWord "Word" == False

-}
isValidWord : String -> Bool
isValidWord word =
    String.length word >= 4 && String.all Char.isLower word


{-| Pre-computes an indexed entry for a word string.

Calculates the 32-bit character bitmask and the distinct letter popcount,
caching them alongside the raw string for constant-time candidate pruning.

Examples:

    (indexWord "rust").popcount == 4

    (indexWord "noon").popcount == 2

-}
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


{-| Inserts a candidate word into a length-partitioned dictionary index.

Computes the indexed entry and appends it to the bucket corresponding to the
string length.

Examples:

    insertWord "rust" Dict.empty

-}
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


{-| Builds a length-partitioned index from a list of candidate words.

Filters out words that fail `isValidWord` before populating the index dictionary
by length.

Examples:

    fromWords [ "care", "race", "cat" ]
        |> wordsOfLength 4
        |> List.length
        == 2

-}
fromWords : List String -> WordIndex
fromWords wordList =
    List.filter isValidWord wordList
        |> List.foldr insertWord Dict.empty


{-| Parses raw dictionary text into candidate words.

Splits content by line, trims surrounding whitespace, discards non-lowercase
ASCII words or words under 4 letters, and partitions entries into a `WordIndex`.

Examples:

    parse "care\nrace\ncat\n"
        |> wordsOfLength 4
        |> List.map .word
        == [ "care", "race" ]

-}
parse : String -> WordIndex
parse content =
    String.lines content
        |> List.map String.trim
        |> fromWords


{-| Flattens an indexed dictionary into an ordered list of candidate words.

Traverses length buckets in ascending key order and collects the words.

Examples:

    parse "care\nrace\n"
        |> words
        == [ "care", "race" ]

-}
words : WordIndex -> List String
words idx =
    Dict.values idx
        |> List.concatMap (List.map .word)


{-| Retrieves candidate words of a specific length from the dictionary index.

Returns an empty list when no candidate words of the requested length exist.

Examples:

    parse "care\nrace\n"
        |> wordsOfLength 4
        |> List.map .word
        == [ "care", "race" ]

    parse "care\nrace\n"
        |> wordsOfLength 7
        == []

-}
wordsOfLength : Int -> WordIndex -> List IndexedWord
wordsOfLength len idx =
    Dict.get len idx
        |> Maybe.withDefault []


{-| Asynchronously fetches the dictionary text file over HTTP.

Dispatches an HTTP GET request to the `"dictionary"` endpoint and routes the
completed response into the TEA message pipeline via the provided constructor.

-}
fetch : (Result Http.Error String -> msg) -> Cmd msg
fetch toMsg =
    Http.get
        { url = "dictionary"
        , expect = Http.expectString toMsg
        }


{-| Converts an HTTP failure error into a user-facing explanation.

Translates low-level network and HTTP status failures into descriptive
Australian English text suitable for display in UI alert banners.

Examples:

    errorToString Http.NetworkError
        == "Network connection failed while loading dictionary."

    errorToString Http.Timeout
        == "Network request timed out while loading dictionary."

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
