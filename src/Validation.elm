module Validation exposing
    ( Validation
    , andMap
    , fail
    , keep
    , succeed
    )

{-| Applicative validation accumulating all errors in a list.
Mirrors Data.Validation from Haskell.
-}


type alias Validation err a =
    Result (List err) a


succeed : a -> Validation err a
succeed value =
    Ok value


fail : err -> Validation err a
fail err =
    Err [ err ]


andMap : Validation err a -> Validation err (a -> b) -> Validation err b
andMap valA valFn =
    case ( valFn, valA ) of
        ( Ok fn, Ok a ) ->
            Ok (fn a)

        ( Err errs1, Ok _ ) ->
            Err errs1

        ( Ok _, Err errs2 ) ->
            Err errs2

        ( Err errs1, Err errs2 ) ->
            Err (errs1 ++ errs2)


keep : Validation err () -> Validation err a -> Validation err a
keep check valA =
    case ( valA, check ) of
        ( Ok a, Ok () ) ->
            Ok a

        ( Err errs1, Ok () ) ->
            Err errs1

        ( Ok _, Err errs2 ) ->
            Err errs2

        ( Err errs1, Err errs2 ) ->
            Err (errs1 ++ errs2)
