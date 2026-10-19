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

Wraps the value in an `Ok` constructor without any accumulated errors.

Examples:

    succeed 42 == Ok 42

    succeed "hello" == Ok "hello"

-}
succeed : a -> Validation err a
succeed value =
    Ok value


{-| Construct a failed validation carrying a single error in a list.

Wraps the provided domain error into a singleton list inside `Err`.

Examples:

    fail "Invalid size" == Err [ "Invalid size" ]

-}
fail : err -> Validation err a
fail err =
    Err [ err ]


{-| Sequence validation contexts, applying a wrapped function to a wrapped
argument while accumulating all errors in sequence order.

Unlike standard monadic `Result.andThen` which halts at the first encountered
error, `andMap` evaluates both contexts and concatenates their error lists when
both fail (`errs1 ++ errs2`). This enables collecting all validation errors
across form fields simultaneously.

Examples:

    succeed (+)
        |> andMap (succeed 2)
        |> andMap (succeed 3)
        == Ok 5

    succeed (+)
        |> andMap (fail "First error")
        |> andMap (fail "Second error")
        == Err [ "First error", "Second error" ]

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

Useful for asserting cross-field invariant constraints where the validation
check produces `()` on success, appending any check failure errors to the
accumulated error list without altering the successful value.

Examples:

    succeed "valid"
        |> keep (succeed ())
        == Ok "valid"

    succeed "valid"
        |> keep (fail "Invariant violated")
        == Err [ "Invariant violated" ]

    fail "Primary error"
        |> keep (fail "Invariant violated")
        == Err [ "Primary error", "Invariant violated" ]

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
