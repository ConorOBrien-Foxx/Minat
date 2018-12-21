# Minat

An experimental version of Attache, which compiles to things.

## Motivation

I want to start with efficiency in mind.

```
Print => 0:10
```

Might be compiled to

```ruby
(0..10).each &Globals["Print"]
```

or

```
f[x, y, z] := x + 2 * y + z

min[x, y] :: {
    If[x < y, x, y]
}

Print[min[f[1, 2, 3], 4]]
```

to

```ruby
Globals["f"] = Function.new(lambda { |scope, args|
    x, y, z = args
    x + 2 * y + z
})
Globals["min"] = Function.new(lambda { |scope, args|
    x, y = args
    (x < y) ? x : y
})

Globals["Print"][scope,
    Globals["min"][scope,
        Globals["f"][scope,
            1, 2, 3
        ],
        4
    ]
]
```
