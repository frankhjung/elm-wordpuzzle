# Elm Quick Start (for Haskell & Python Devs)

Elm is a pure, functional programming language that compiles to JavaScript. Since you know Haskell, you'll feel right at home with the ML-family syntax, currying, and algebraic data types. Because you know Python, you'll appreciate Elm's emphasis on practicality, clear error messages, and strict evaluation (Elm is **not** lazy).

Elm's primary philosophy is **"No Runtime Exceptions."** It achieves this by forbidding side effects outside its managed architecture and completely removing `null` (using `Maybe` instead).

---

## 1. Syntax Translation: Haskell & Python to Elm

### Type Annotations and Basic Syntax
Elm reverses the colon usage of Haskell, adopting standard ML syntax. 
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
Elm's records look like Python dictionaries but behave like Haskell records (with much better update syntax). Record access uses the dot `.`, which is why Elm uses `<<` and `>>` for function composition instead of Haskell's `.`.

```elm
type alias User = 
    { name : String, age : Int }

alice : User
alice = 
    { name = "Alice", age = 28 }

-- Access (Like Python)
aliceName = alice.name

-- Record Update (Immutable)
olderAlice = { alice | age = alice.age + 1 }
```

### Custom Types (Haskell's `data`)
Elm uses `type` for Algebraic Data Types (Haskell's `data`) and `type alias` for type synonyms (Haskell's `type`).

```elm
-- Haskell: data Status = Loading | Loaded String | Failed
type Status
    = Loading
    | Loaded String
    | Failed

-- Pattern matching is done with 'case ... of'
getStatusMessage : Status -> String
getStatusMessage status =
    case status of
        Loading ->
            "Please wait..."
        
        Loaded data ->
            "Data: " ++ data
            
        Failed ->
            "Error occurred"
```

---

## 2. Key Differences from Haskell (The "Gotchas")

To keep the language simple and accessible, Elm stripped out several advanced Haskell features:

1. **No Typeclasses:** There is no `Eq`, `Ord`, `Show`, or `Monad`. 
   * You cannot write a generic `fmap`. You must explicitly use `List.map`, `Maybe.map`, or `Result.map`.
   * You convert to strings using specific functions like `String.fromInt`.
2. **Strict Evaluation:** Like Python, Elm evaluates strictly. Infinite lists will crash your program.
3. **Strings are not Lists of Chars:** Elm has a native `String` type. Use `++` to concatenate them.
4. **No `IO` Monad:** Side effects are handled entirely by **The Elm Architecture (TEA)**.

---

## 3. The Elm Architecture (TEA)

Because there is no `IO` Monad, you cannot just "print" or "fetch" mid-function. Elm applications are built on a strict Model-View-Update loop (which inspired Redux). 

Every Elm app has three parts:
1. **Model:** The state of your application (like a React state or a Python dataclass).
2. **View:** A pure function that takes the `Model` and returns HTML.
3. **Update:** A pure function `Msg -> Model -> Model` that takes an event (`Msg`) and the current state, and returns the new state.

Here is a complete, minimal Elm application (a counter):

```elm
import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

-- MAIN
main =
  Browser.sandbox { init = init, update = update, view = view }

-- 1. MODEL
type alias Model = Int

init : Model
init = 0

-- 2. UPDATE (The "Events")
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

-- 3. VIEW (Pure UI projection)
view : Model -> Html Msg
view model =
  div []
    [ button [ onClick Decrement ] [ text "-" ]
    , div [] [ text (String.fromInt model) ]
    , button [ onClick Increment ] [ text "+" ]
    ]
```

---

## 4. Handling Side Effects (Commands)

When you need a side effect (like making an HTTP request or generating a random number), you don't return just a `Model` from your `update` function. You return a tuple of `(Model, Cmd Msg)`.

A `Cmd` (Command) is an instruction to the Elm runtime. 
* Elm runtime executes the command (e.g., fetches data).
* When the command finishes, the runtime feeds the result back into your `update` function as a new `Msg`.

```elm
-- Notice the return type is now (Model, Cmd Msg)
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        RollDice ->
            -- State doesn't change yet, but we ask the runtime for a random number
            ( model, Random.generate NewFace (Random.int 1 6) )

        NewFace newNumber ->
            -- The runtime calls us back with the result
            ( newNumber, Cmd.none )
```

---

## 5. Tooling Quick Start

Elm has built-in tooling that eliminates the need for complex bundlers when starting out.

1. **Install Elm:** 
   `npm install -g elm`
2. **Initialize a project:** 
   `elm init` (This creates an `elm.json` and a `src/` directory).
3. **Start the development server:** 
   `elm reactor` 
   *(Navigate to `http://localhost:8000` and click your `.elm` file. It will compile on the fly).*
4. **Build for production:**
   `elm make src/Main.elm --optimize --output=main.js`

## Summary Checklist for Python/Haskell Devs
* **Variables/Functions:** pure, immutable, and curried (like Haskell).
* **Data Structures:** strictly evaluated (like Python).
* **Control Flow:** Everything is an expression. Use `if ... then ... else` or `case ... of`.
* **Architecture:** `Model` -> `View` -> `Update`. Yield side-effects as `Cmd`s to the runtime.