[<- back to index](index.md)

# Grog language

Instructions can be:

 - `if <expression...>:`
 - `elif <expression...>:`
 - `else:`
 - `loop:`
 - `break`
 - or a command

# Command reference

|      Command      |                  Description                  |   Sintaxis                                                                            |
|:-----------------:|:--------------------------------------------- |:------------------------------------------------------------------------------------- |
| **load_room**     | Loads a new room.                             | `            .load_room    <room_id>                                                ` |
| **enable_input**  | Enables input and show controls.              | `            .enable_input                                                          ` |
| **disable_input** | Disable input and hides controls.             | `            .disable_input                                                         ` |
| **curtain_up**    | Curtain up.                                   | `            .curtain_up                                                            ` |
| **wait**          | Waits `delay` seconds.                        | `            .wait         <delay> [skippable=true\|false]                          ` |
| **say**           | The environment or an item says something.    | ` [<subject>].say          <speech> [skippable=true\|false]  [duration=<delay>]     ` |
| **walk**          | Player or item walks to position.             | `   <subject>.walk         to=<target_name>                                         ` |
| **teleport**      | Moves the player or item.                     | `   <subject>.teleport     to=<target_name>                                         ` |
| **set**           | Sets the value of a global variable.          | `            .set          <var_name>=<expression...>                               ` |
| **enable**        | Enable a scene item (loaded or not).          | `   <sc_item>.enable                                                                ` |
| **disable**       | Disable a scene item (loaded or not).         | `   <sc_item>.disable                                                               ` |
| **add**           | Increments an inventory item's count.         | `  <inv_item>.add                                                                   ` |
| **remove**        | Decrements an inventory item's count.         | `  <inv_item>.remove                                                                ` |
| **play**          | Sets a state to a scene item (loaded or not). | `   <sc_item>.play         <animation_name>                                         ` |
| **set_tool**      | Sets a scene/inventory item as "tool".        | `      <item>.set_tool     <verb_name>                                              ` |
| **debug**         | Shows evaluation result in console.           | `            .debug        <expression...>                                          ` |
| **end**           | Ends the game.                                | `            .end                                                                   ` |


<!-- |                   |                                               | `                                                                                   ` | -->


## set_tool

 - `<verb_name>`: it's the name of the verb

It can be used with inventory items (even if they are not in the inventory) and with **loaded** and **enabled** scene items.

[<- back to index](index.md)