[<- back to index](index.md)

# Requests sent from client to server

|      Signature                                                          |                  Description                                |
| ----------------------------------------------------------------------- | ----------------------------------------------------------- |
|  `start_game_request(root_node: Node)                                `  |  Start the game.                                            |
|  `skip_request()                                           `  |  Skip current task if it is skippable. |
|  `go_to_request(global_position)                                     `  |  Try to walk with the player to the specified global position (or closest navigation point). |
|                                                                         |                                                             |
|                                                                         |                                                             |

<!---
|                                                                         |                                                             |
-->



# Events sent from server to client

|      Signature                                                          |                  Description                                |
| ----------------------------------------------------------------------- | ----------------------------------------------------------- |
|  `game_started(player: Node)                                         `  |  Game started.                                              |
|  `game_ended()                                                       `  |  Game ended (caused by 'end' command or client stop request). |
|  `room_loaded(room: Node)                                            `  |  Room loaded; then will receive 'item_enabled' for each loaded (and non-globally-disabled) item in room.  |
|  `curtain_up()                                                       `  |  Curtain up.                                                |
|  `wait_started(duration: float, skippable: bool)                     `  |  Start waiting 'duration' seconds (maybe skippable by client).        |
|  `say(who: Node, speech: String, duration: float, skippable: bool)   `  |  The environment or some item says something; the client must show it. |
|  `wait_ended()                                                       `  |  The wait (indicated by a 'wait' or a 'say') is over (either timed out or skipped by client). |
|  `item_enabled(item: Node)                                           `  |  Scene item is client-enabled, i.e. it's loaded and non-globally disabled (client can interact with it). |
|  `item_disabled(item: Node)                                          `  |  Scene item is client-disabled (either unloaded or disabled in practice). Client must clear it. |
|  `item_added(item_model: Node, instance_number: int)                 `  |  Inventory item's instance added.                      |
|  `item_removed(item_model: Node, instance_number: int)               `  |  Inventory item's instance is removed.                     |

[<- back to index](index.md)