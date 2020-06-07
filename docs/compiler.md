
[<- back to grog index](index.md)

# Tokenization

The tokenizer takes one line and reads one character at each step. If it reads:

 - an operator: it generates an operator token.
 - a quote: it starts reading a quoted string until the closing quote.
 - a number `0-9`: it starts reading an int or float expression; note that '.5' will be parsed as an (invalid) command.
 - a character in `a-z A-Z _ . / $ *`: it starts reading a standard token formed by those characters plus `0-9`;
 then the token is verified and classified as keyword, identifier, command or pattern.


## Token rules

```
TOKEN =          STANDARD_TOKEN | NUMBER | QUOTE | OPERATOR
STANDARD_TOKEN = KEYWORD | IDENTIFIER | COMMAND | PATTERN

KEYWORD =        if | elif | else | not | and | or | true | false

IDENTIFIER =     IDENTIFIER_KEY | $IDENTIFIER                  # identifier key or reference to it (can be nested references)
IDENTIFIER_KEY = ID_SEGMENT(/ID_SEGMENT)*
ID_SEGMENT =     [a-zA-Z0-9\_]+

COMMAND =        .COMMAND_NAME | IDENTIFIER.COMMAND_NAME
COMMAND_NAME =   load_room | enable_input | etc...

PATTERN =        [a-zA-Z0-9\_\/\*]+

QUOTE =          "anything between quotes"

OPERATOR =       :   >   <   =   +   -   (   )

NUMBER =         INT | FLOAT
INT =            [0-9]+
FLOAT =          [0-9]+\.[0-9]+
```

# Compiling

## Compile rules

```
to be done
```


[<- back to grog index](index.md)
