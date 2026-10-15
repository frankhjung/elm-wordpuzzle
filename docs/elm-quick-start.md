# Elm Quick Start (for Haskell and Python Developers)

Elm is a pure, functional programming language that compiles to JavaScript.
Since you know Haskell, you will feel at home with the ML-family syntax,
currying, and algebraic data types. Because you know Python, you will appreciate
Elm's emphasis on practicality, clear compiler diagnostics, and strict
evaluation (Elm is **not** lazy).

Elm's primary philosophy is **"No Runtime Exceptions."** It achieves this by
forbidding side effects outside its managed architecture and completely
eliminating `null` (using `Maybe` instead).

## 1. Syntax Translation: Haskell and Python to Elm

### Type Annotations and Basic Syntax

Elm reverses the colon usage of Haskell, adopting standard ML syntax:

* `:` means "has type" (Haskell's `::` or Python's `def f(x: int) -> int:`)
* `::` means "cons" (Haskell's `:`)

```elm
-- Haskell: add :: Int -> Int -> Int
add : Int -> Int -> Int
add x y =
    x + y

-- Python: names = ["Alice", "Bob"]
names : List String
names =
    "Alice" :: "Bob" :: [] -- or ["Alice", "Bob"]
```

### Records (Python Dictionaries, but Type-Safe)

Elm records look like Python dictionaries but behave like Haskell records (with
much cleaner update syntax). Record field access uses the dot `.`.

```elm
type alias User =
    { name : String, age : Int }

alice : User
alice =
    { name = "Alice", age = 28 }

-- Access (like Python)
aliceName =
    alice.name

-- Record Update (immutable)
olderAlice =
    { alice | age = alice.age + 1 }
```

### Pipelines over Function Composition

While Elm supports `<<` and `>>` for point-free composition, idiomatic Elm
strongly discourages composition operators. Instead, Elm embraces forward
pipelines (`|>`), making data transformations read naturally from top to bottom:

```elm
-- Idiomatic Elm: clear, debuggable pipeline
sanitised =
    rawInput
        |> String.trim
        |> String.toLower
        |> String.left 8
```

### Custom Types (Haskell's `data`)

Elm uses `type` for Algebraic Data Types (Haskell's `data`) and `type alias` for
type synonyms (Haskell's `type`). The 4-state `RemoteData` sum type used in this
project exemplifies impossible-state elimination:

```elm
-- Haskell: data RemoteData e a = NotAsked | Loading | Failure e | Success a
type RemoteData error data
    = NotAsked
    | Loading
    | Failure error
    | Success data

-- Pattern matching is done with 'case ... of'
getStatusMessage : RemoteData String String -> String
getStatusMessage status =
    case status of
        NotAsked ->
            "Ready."

        Loading ->
            "Loading words..."

        Failure err ->
            "Error: " ++ err

        Success data ->
            "Loaded payload: " ++ data
```

## 2. Key Differences from Haskell (The Gotchas)

To keep the language simple and accessible, Elm stripped out several advanced
Haskell features:

1. **No Typeclasses:** There is no `Eq`, `Ord`, `Show`, or `Monad`.
   * You cannot write a generic `fmap`. You must explicitly use `List.map`,
     `Maybe.map`, or `Result.map`.
   * Convert types using specific functions like `String.fromInt`.
2. **Strict Evaluation:** Like Python, Elm evaluates strictly. Infinite lists
   will exhaust resources and crash your program.
3. **Strings are not Lists of Chars:** Elm has a native `String` type. Use `++`
   to concatenate them.
4. **No `IO` Monad:** Side effects are handled entirely by **The Elm
   Architecture (TEA)**.

## 3. The Elm Architecture (TEA)

Because there is no `IO` Monad, you cannot print or fetch mid-function. Elm
applications are built on a strict Model-View-Update loop:

1. **Model:** The minimal application state (source of truth).
2. **View:** A pure function `Model -> Html Msg` projecting state to DOM.
3. **Update:** A pure function `Msg -> Model -> ( Model, Cmd Msg )`
   transitioning state in response to events.

Here is a minimal counter application:

```elm
module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

main =
    Browser.sandbox { init = init, update = update, view = view }

type alias Model =
    Int

init : Model
init =
    0

type Msg
    = Increment
    | Decrement

update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            model + 1

        Decrement ->
            model - 1

view : Model -> Html Msg
view model =
    div []
        [ button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model) ]
        , button [ onClick Increment ] [ text "+" ]
        ]
```

## 4. Handling Side Effects (Commands)

When performing side effects (such as making an HTTP request or generating a
random number), your update function returns a tuple `( Model, Cmd Msg )`.

A `Cmd` (Command) is pure data describing an effect for the Elm runtime:

* The runtime executes the command (e.g. fetches data asynchronously).
* When the command completes, the runtime feeds the result back into your
  `update` function as a new `Msg`.

```elm
-- HTTP fetching command example
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchDictionary ->
            ( { model | status = Loading }
            , Http.get
                { url = "dictionary"
                , expect = Http.expectString GotDictionary
                }
            )

        GotDictionary (Ok text) ->
            ( { model | status = Success (Dictionary.parse text) }
            , Cmd.none
            )

        GotDictionary (Err err) ->
            ( { model | status = Failure err }
            , Cmd.none
            )
```

## 5. Tooling and Makefile Workflows

This repository orchestrates all formatting, linting, testing, and compilation
via GNU Make:

1. **Install dependencies:** `make deps`
2. **Format source files:** `make format`
3. **Type-check and lint:** `make check && make lint`
4. **Execute tests:** `make test`
5. **Build production bundle:** `make build`
6. **Launch local server:** `make run`

## Summary Checklist for Python and Haskell Developers

* **Purity:** Functions are pure, immutable, and curried (like Haskell).
* **Evaluation:** Data structures are strictly evaluated (like Python).
* **Control Flow:** Everything is an expression. Use `if ... then ... else` or
  `case ... of`.
* **Architecture:** `Model` -> `View` -> `Update`. Yield side effects as `Cmd`
  data to the runtime.
