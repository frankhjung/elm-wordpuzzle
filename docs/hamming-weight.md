# Hamming Weight (Parallel Popcount) in Elm

The `Dictionary.countBits` function implements a **SWAR** (*SIMD Within A
Register*) divide-and-conquer algorithm to compute the
[Hamming weight](https://en.wikipedia.org/wiki/Hamming_weight) (also known as
*population count* or *popcount*) of a 32-bit integer.

Instead of iterating through all 32 bits in a loop, the algorithm treats a
single 32-bit register as a vector of smaller integers. By applying bitwise
shifts and masks, it sums adjacent bit groups in parallel across 5 logarithmic
stages ($\log_2 32 = 5$), completing the calculation in constant $O(1)$ time.

## Context: Character Bitmasks in `elm-wordpuzzle`

In `elm-wordpuzzle`, words are encoded as 32-bit integer bitmasks so the solver
can test whether a candidate word's letter set is a subset of the puzzle letters
in a single bitwise operation. Each of the 26 letters of the English alphabet is
assigned a bit position from 0 (`a`) to 25 (`z`):

$$\text{mask}(\text{"apple"}) = 2^0 \lor 2^{15} \lor 2^{11} \lor 2^4 = \text{0b00000000000000001000100000010001}$$

Counting the set bits (`1`s) in this bitmask reveals the exact number of
**distinct characters** in the word (`"apple"` has 4 distinct letters: `a`, `e`,
`l`, and `p`). This is used to identify pangrams (words using all 7 distinct
puzzle letters) and score candidate words without allocating intermediate sets
or lists.

## Implementation

From [`src/Dictionary.elm`](../src/Dictionary.elm):

```elm
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
```

## The Core Concept: Parallel Pairwise Addition

Imagine 32 single-digit binary numbers (`0` or `1`) lined up side-by-side inside
a single 32-bit integer:

1. **Stage 1 (2-bit sums):** Add adjacent 1-bit numbers to form sixteen 2-bit
   counts (values `0` to `2`).
2. **Stage 2 (4-bit sums):** Add adjacent 2-bit counts to form eight 4-bit
   nibbles (values `0` to `4`).
3. **Stage 3 (8-bit sums):** Add adjacent 4-bit nibbles to form four 8-bit
   bytes (values `0` to `8`).
4. **Stage 4 (16-bit sums):** Add adjacent 8-bit bytes into 16-bit half-words
   (values `0` to `16`).
5. **Stage 5 (32-bit sum):** Add the two 16-bit half-words to get the final
   count (values `0` to `32`) in the lowest 6 bits.

| Stage | Binding | Shift    | Hex Mask     | Binary Pattern (Repeating) | Group Width | Max Sum            |
| :---- | :------ | :------- | :----------- | :------------------------- | :---------- | :----------------- |
| **1** | `n1`    | `>>> 1`  | `0x55555555` | `01010101...`              | 2 bits      | `2` (`0b10`)       |
| **2** | `n2`    | `>>> 2`  | `0x33333333` | `00110011...`              | 4 bits      | `4` (`0b0100`)     |
| **3** | `n3`    | `>>> 4`  | `0x0F0F0F0F` | `00001111...`              | 8 bits      | `8` (`0b00001000`) |
| **4** | `n4`    | `>>> 8`  | *(None)*     | *(Unmasked addition)*      | 16 bits     | `16` (`0x10`)      |
| **5** | `n5`    | `>>> 16` | `0x0000003F` | `00111111` (low 6 bits)    | 32 bits     | `32` (`0x20`)      |

## Step-by-Step Walkthrough

To see how the bits fold together, we trace the algorithm using the example from
the docstring:

$$n = \text{0b10100101} \quad (\text{decimal } 165)$$

For clarity, we display the lower 8 bits (the upper 24 bits are all `0` and
behave identically). Notice that `0b10100101` has **4** bits set.

### Stage 1: Count Bits in Each 2-Bit Pair (`n1`)

```elm
n1 =
    n - Bitwise.and (Bitwise.shiftRightZfBy 1 n) 0x55555555
```

- **What the mask does:** `0x55555555` is `0b01010101...` in binary. It isolates
  the even-indexed bits (bits 0, 2, 4, ...).
- **Why subtraction works:** Consider a single 2-bit pair $b_1 b_0$. Its numeric
  value as a 2-bit integer is $2b_1 + b_0$. We want the sum of its bits, which
  is $b_1 + b_0$. Shifting right by 1 moves $b_1$ into the $b_0$ position, and
  masking with `0b01` isolates $b_1$. Subtracting $b_1$ from $2b_1 + b_0$ gives:

$$(2b_1 + b_0) - b_1 = b_1 + b_0$$

| Pair Value ($b_1 b_0$) | Decimal ($2b_1 + b_0$) | Shifted & Masked ($b_1$) | Subtracted ($b_1 + b_0$) | Binary Result |
| :--------------------: | :--------------------: | :----------------------: | :----------------------: | :-----------: |
|          `00`          |          `0`           |           `0`            |       `0 - 0 = 0`        | `00` (0 bits) |
|          `01`          |          `1`           |           `0`            |       `1 - 0 = 1`        | `01` (1 bit)  |
|          `10`          |          `2`           |           `1`            |       `2 - 1 = 1`        | `01` (1 bit)  |
|          `11`          |          `3`           |           `1`            |       `3 - 1 = 2`        | `10` (2 bits) |

**Tracing `n = 0b10100101` (grouped into 2-bit pairs):**

```text
  n                     =  10  10  01  01
  n >>> 1               =  01  01  00  10
  (n >>> 1) & 01010101  =  01  01  00  00
  --------------------------------------- (Subtract)
  n1                    =  01  01  01  01   ( counts: 1, 1, 1, 1 )
```

Each 2-bit slot now holds the number of `1`s that were originally in that pair.

### Stage 2: Sum Adjacent 2-Bit Counts into 4-Bit Nibbles (`n2`)

```elm
n2 =
    Bitwise.and n1 0x33333333
        + Bitwise.and (Bitwise.shiftRightZfBy 2 n1) 0x33333333
```

- **What the mask does:** `0x33333333` is `0b00110011...` in binary. It selects
  alternating 2-bit pairs.
- **Why masking before addition is required:** Each 2-bit pair holds at most `2`
  (`0b10`). If we added without masking first, adjacent pairs could carry into
  one another. Masking both the unshifted and shifted values isolates the lower
  and upper 2-bit pairs of each 4-bit nibble before summing them. The maximum
  sum in any 4-bit nibble is $2 + 2 = 4$ (`0b0100`), which fits comfortably in
  4 bits.

**Tracing `n1 = 0b01010101` (grouped into 4-bit nibbles):**

```text
  n1                    =  0101  0101
  n1 & 00110011         =  0001  0001   ( lower 2-bit counts: 1, 1 )
  (n1 >>> 2) & 00110011 =  0001  0001   ( upper 2-bit counts: 1, 1 )
  ----------------------------------- (Add)
  n2                    =  0010  0010   ( nibble counts: 2, 2 )
```

Each 4-bit nibble now contains the count of set bits from that 4-bit region
(`0010` = 2 in the upper nibble, `0010` = 2 in the lower nibble).

### Stage 3: Sum Adjacent 4-Bit Nibbles into 8-Bit Bytes (`n3`)

```elm
n3 =
    Bitwise.and (n2 + Bitwise.shiftRightZfBy 4 n2) 0x0F0F0F0F
```

- **What the mask does:** `0x0F0F0F0F` is `0b00001111...` in binary, isolating
  the lower 4 bits of every byte.
- **Why we can add *before* masking here:** In `n2`, the maximum value inside
  any 4-bit nibble is `4` (`0b0100`). Adding two adjacent nibbles yields at
  most $4 + 4 = 8$ (`0b1000`), which never exceeds 4 bits (`15` is the 4-bit
  limit). Because no carry can overflow from the lower nibble into the upper
  nibble during addition, we can add `n2` and `n2 >>> 4` first, and then mask
  away the upper nibbles with `0x0F0F0F0F`.

**Tracing `n2 = 0b00100010` (8-bit byte view):**

```text
  n2                    =  00100010
  n2 >>> 4              =  00000010
  n2 + (n2 >>> 4)       =  00100100
  ... & 00001111        =  00000100   ( byte count: 4 )
```

Now every 8-bit byte holds the sum of set bits in that byte (from `0` to `8`).

### Stage 4 & Stage 5: Fold Bytes Across the 32-Bit Word (`n4`, `n5`)

```elm
n4 =
    n3 + Bitwise.shiftRightZfBy 8 n3

n5 =
    n4 + Bitwise.shiftRightZfBy 16 n4
```

- **Why no intermediate masks are needed:** After Stage 3, each byte holds a
  count of at most `8`, and the total across all four bytes is at most `32`
  (`0b00100000`). Since a single byte can hold up to `255` without overflowing
  into the next byte, the bytes can be summed directly without masking between
  shifts:
  - `n4` adds Byte 1 into Byte 0, and Byte 3 into Byte 2.
  - `n5` adds the upper 16-bit sum into the lower 16-bit sum, placing the grand
    total of all four bytes into the lowest byte.

**Tracing `n3` across all 4 bytes (`[Byte 3, Byte 2, Byte 1, Byte 0]`):**

```text
  n3                    =  [ 0,  0,  0,  4 ]
  n4 = n3 + (n3 >>> 8)  =  [ 0,  0,  0,  4 ]
  n5 = n4 + (n4 >>> 16) =  [ 0,  0,  0,  4 ]
```

### Final Mask: Extract the 6-Bit Result

```elm
Bitwise.and n5 0x3F
```

- **Why `0x3F`?** The maximum number of set bits in a 32-bit integer is `32`
  (`0b100000`), which requires 6 bits to represent. The hexadecimal constant
  `0x3F` is `0b00111111` (decimal `63`). Masking `n5` with `0x3F` clears away
  any leftover intermediate values sitting in the upper bytes and extracts the
  final count (`4`).

## Elm Specifics: Why `Bitwise.shiftRightZfBy`?

In Elm, `Bitwise` operations follow JavaScript's 32-bit bitwise semantics.
There are two right-shift functions in Elm's `Bitwise` module:

1. `Bitwise.shiftRightBy` (`>>`): **Sign-propagating right shift.** If the 31st
   bit (the sign bit) is `1`, shifting right fills the newly vacated high bits
   with `1`s instead of `0`s.
2. `Bitwise.shiftRightZfBy` (`>>>`): **Zero-fill (logical) right shift.** Always
   shifts in `0`s from the left, treating the 32-bit word as an unsigned bit
   array.

Using `Bitwise.shiftRightZfBy` is essential here so that if the 31st bit of `n`
is set, shifting right does not pollute the upper bit groups with sign-extension
`1`s.

## Verifying Invariants with `elm-test`

We can verify the correctness of `countBits` against a naive reference
implementation and test its algebraic properties using `elm-test` fuzzers:

```elm
module DictionaryTest exposing (suite)

import Bitwise
import Dictionary exposing (countBits)
import Expect
import Fuzz
import Test exposing (Test, describe, fuzz, fuzz2, test)


suite : Test
suite =
    describe "Dictionary.countBits"
        [ test "zero has 0 set bits" <|
            \_ ->
                countBits 0
                    |> Expect.equal 0
        , test "0b10100101 has 4 set bits" <|
            \_ ->
                countBits 0xA5
                    |> Expect.equal 4
        , fuzz Fuzz.int "matches naive bit-by-bit fold across 32-bit ints" <|
            \n ->
                let
                    masked =
                        Bitwise.shiftRightZfBy 0 n
                in
                countBits masked
                    |> Expect.equal (naiveCountBits masked)
        , fuzz2 Fuzz.int Fuzz.int "inclusion-exclusion law for bitwise OR and AND" <|
            \a b ->
                let
                    u =
                        Bitwise.shiftRightZfBy 0 a

                    v =
                        Bitwise.shiftRightZfBy 0 b

                    orCount =
                        countBits (Bitwise.or u v)

                    andCount =
                        countBits (Bitwise.and u v)
                in
                (orCount + andCount)
                    |> Expect.equal (countBits u + countBits v)
        ]


{-| Naive O(32) reference implementation for property testing.
-}
naiveCountBits : Int -> Int
naiveCountBits n =
    List.range 0 31
        |> List.foldl
            (\bit acc ->
                acc + Bitwise.and (Bitwise.shiftRightZfBy bit n) 1
            )
            0
```

## References

- [Hamming weight — Wikipedia](https://en.wikipedia.org/wiki/Hamming_weight)
- Henry S. Warren Jr., *Hacker's Delight*, 2nd ed., Addison-Wesley, 2012,
  Chapter 5: "Counting Bits".
- [Elm `Bitwise` Package Documentation](https://package.elm-lang.org/packages/elm/core/latest/Bitwise)
