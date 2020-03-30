
# Tokenization:

The tokenizer takes one line and reads one character at each step. If it reads:

 - an operator: it generates an operator token.
 - a quote: it starts reading a quoted string until the closing quote.
 - a number `0-9`: it starts reading an int or float expression.
 - a character in `a-z A-Z _ / $ .`: it starts reading a standard token formed by those characters plus `0-9`; then the token is classified as keyword, identifier or command.

```
TOKEN =          STANDARD_TOKEN | NUMBER | QUOTE | OPERATOR
STANDARD_TOKEN = KEYWORD | IDENTIFIER | COMMAND

KEYWORD =        if | else | not | and | or | true | false

IDENTIFIER =     IDENTIFIER_KEY | $IDENTIFIER
IDENTIFIER_KEY = ID_SEGMENT(/ID_SEGMENT)*
ID_SEGMENT =     [a-zA-Z\_][a-zA-Z\_0-9]*

COMMAND =        IDENTIFIER.COMMAND_NAME
COMMAND_NAME =   [a-z\_]+

QUOTE =          "anything between quotes"

OPERATOR =       :   >   <   =   +   -   (   )

NUMBER =         ([0-9]+|[0-9]*\.[0-9]+)
```