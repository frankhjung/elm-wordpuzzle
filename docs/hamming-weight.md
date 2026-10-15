# Hamming Weight / Bit Popcount in the Dictionary Index

The `countBits` helper in `src/Dictionary.elm` calculates the number of set bits in a 32-bit integer. This is a classic bit-twiddling technique known as the Hamming weight or popcount.

```elm
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

## Why this exists

The word puzzle solver stores each word as a bitmask of its letters. Each lowercase letter is mapped to a bit position, so a word like `apple` becomes a mask with bits set for the letters it contains.

For example, if the letters are represented as bits in a 26-bit mask, then:

- `a` might be bit 0
- `b` bit 1
- `c` bit 2
- and so on

The algorithm then asks: how many distinct letters are present in this word? That answer is the number of set bits in the mask.

This is exactly what `countBits` returns.

## How the algorithm works

The function repeatedly reduces the bit pattern in stages:

1. It groups bits in pairs and sums them.
2. It then groups the results in 2-bit chunks.
3. It continues with 4-bit groups, then 8-bit groups, then 16-bit groups.
4. Finally, it masks the result to keep the low 6 bits.

This is much faster than looping over every bit in the integer and checking whether it is set.

The pattern is a standard constant-time bit manipulation optimization for computing popcount on 32-bit values.

## Example

```elm
countBits 0 == 0
countBits 0b10100101 == 4
```

`0b10100101` has four set bits (`1`, `0`, `1`, `0`, `0`, `1`, `0`, `1`), so the result is `4`.

## Why this matters for the solver

The dictionary index precomputes for each valid word:

- the word itself
- a 32-bit letter mask
- the number of distinct letters (`popcount`)

That makes later matching logic much faster because the puzzle solver can compare masks and counts without repeatedly scanning the characters in each word.

The function is therefore an optimization that supports fast word comparisons in the bitmask-based solver.
