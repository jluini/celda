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
| **teleport**      | Moves the player or item.                     | `   <subject>.teleport     to=<target_name>   [angle=<int>]                         ` |
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


## teleport

Instantly teleports an item or actor to the position specified by `target_name`.
The target must be either a (loaded and enabled) scene item or a plain node name.

The item (or actor) angle can be set aswell. If the target is an item the angle used defaults to its interaction angle.
In the case of plain nodes it remains unchanged when not specified.

	you.teleport to=position1                            # teleports the player to a node 'position1' keeping the angle
	you.teleport to=position1  angle=180                 # changes the player angle aswell

	you.teleport to=room/item1                           # teleports the player to an item (using its interaction angle)
	you.teleport to=room/item1  angle=90                 # overrides the item's interaction angle





[<- back to index](index.md)