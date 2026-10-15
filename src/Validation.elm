module Validation exposing
    ( Validation
    , succeed, fail
    , andMap, keep
    )

{-| Applicative validation accumulating all errors in a list.
Mirrors `Data.Validation` from Haskell.


# Types

@docs Validation


# Constructors

@docs succeed, fail


# Combinators

@docs andMap, keep

-}


{-| Represents a validation result holding either a valid value or a list
of accumulated errors.
-}
type alias Validation err a =
    Result (List err) a


{-| Lift a pure value into a successful validation context.
-}
succeed : a -> Validation err a
succeed value =
    Ok value


{-| Construct a failed validation carrying a single error in a list.
-}
fail : err -> Validation err a
fail err =
    Err [ err ]


{-| Sequence validation contexts, applying a wrapped function to a wrapped
argument while accumulating all errors in sequence order.
-}
andMap : Validation err a -> Validation err (a -> b) -> Validation err b
andMap valA valFn =
    case ( valFn, valA ) of
        ( Ok fn, Ok a ) ->
            Ok (fn a)

        ( Err errs1, Err errs2 ) ->
            Err (errs1 ++ errs2)

        ( Err errs, Ok _ ) ->
            Err errs

        ( Ok _, Err errs ) ->
            Err errs


{-| Run an auxiliary validation check and discard its unit result, retaining
the primary validated value while accumulating any check errors.
-}
keep : Validation err () -> Validation err a -> Validation err a
keep check valA =
    case ( valA, check ) of
        ( Ok a, Ok () ) ->
            Ok a

        ( Err errs1, Err errs2 ) ->
            Err (errs1 ++ errs2)

        ( Err errs, Ok () ) ->
            Err errs

        ( Ok _, Err errs ) ->
            Err errs
