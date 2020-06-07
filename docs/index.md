[<- back to celda](..)

# Grog documentation

**Grog** is a Godot's framefork for *point &amp; click adventure games*. Its name stands for "Godot's recipe of grog";
note that this acronym is **not** recursive as the *grog* word it contains refers to a well-known fantasy drink and
not to the framework itself.

It works in Godot 3.2.

## Index

A detailed (but still incomplete) documentation of each part of the system is here:

 - [Grog language](grog_language.md)
 - [Server-client communication](server_client.md)
 - [Compiler](compiler.md)

## Overview

The grog system has a client-server model.

The **server** reads the *game data* (that contains the *game script* written in [grog language](grog_language.md))
and runs it following the instructions from the script and the requests sent by the client; it loads the main
game objects (the currently loaded *room* or scene with its items and the *actors* or characters) within a root node specified by the client,
manages the characters movement and emits *game events* so that the client can show them to the user.

The **client** indicates a root node (which will act as a viewport) through the *start_game_request*, sends the user commands
to the server and responds to its game events. It's not a dumb passive terminal; while the server manages the scene, the
characters and the general timing the client has important responsibilities aswell:

- shows the **speech** (texts said by the actors, items or the environment)
- displays the **inventory** items
- influences the pace of the game, as there are situations in which the server gets blocked until it receives a *skip_request* from the client
(representing the user wants to advance in the play); in some other situations the server doesn't get blocked but still can be accelerated by
a skip request from the client
- transmits the user's intention to walk to some place or to perform interactions with items
- reproduces the music and the sounds, as these are generic events without a special meaning from the server's point of view
(the song changes are actually broadcasted as modular events and the *fede-loopin* module takes care of them)

There's a list of the client requests and game events [here](docs/server_client.md).

# Grog games

The logic and semantics of a grog game is under development and needs a full documentation. This is a summary.

Grog games belong to the **point &amp; click** genre, considered a subset of the *adventure games* category
<sup>[1](https://en.wikipedia.org/wiki/Adventure_game#Point-and-click_adventure_games)</sup>
<sup>[2](https://fr.flossmanuals.net/creating-point-and-click-games-with-escoria/what-is-point-and-click-games/)</sup>.
Games from **LucasArts** like *Monkey Island* are regarded as the most important ones within this genre.

Every grog game has a *game data* or *game script* that defines its contents. This is implemented in the
[simple_game_script Resource](/src/tools/grog/core/simple_game_script.gd) and the **celda** instance of this is
[here](/src/games/celda_escape/juego.tres). The main components of the game data are:

- the list of the *rooms* (or scenes)
- the actor who plays the role of the character controlled by the user (the only one actor supported at the moment)
- the **script** itself; this is coded in the [grog language](grog_language.md) and contains a main routine
(executed when game starts) and a routine for each possible interaction; the **celda** script file is
[here](/src/games/celda_escape/script.grog) (game elements are named in spanish)



[<- back to celda](..)
