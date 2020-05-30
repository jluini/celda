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
| **load\_room**    | Loads a new room.                             | `            .load_room    <room_id> at=<initial_player_position>                   ` |
| **enable\_input** | Enables input and show controls.              | `            .enable_input                                                          ` |
| **disable\_input**| Disable input and hides controls.             | `            .disable_input                                                         ` |
| **curtain\_up**   | Curtain up.                                   | `            .curtain_up                                                            ` |
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

## load_room

If there's a room loaded, lowers the curtain and unloads it. Then loads the new room.

The option `at` indicates the initial positioning of the player. It can be the key of an item in the room of the path to a _plain_ positioning node.
If the option is absent the room is loaded without a player.

The command `curtain_up` is needed after `load_room` to raise the curtain again (the new room will not be visible otherwise).

## curtain_up

Raises the curtain. Needed after load_room.


## set

Sets a new value for a global variable.

	.set number = 5
	.set number = $number + 1
	.set flag = $another_flag and ($number > 4)
	.set text = "hello"
	.set text = $text + ", world"

## say

The environment or an item says something. This needs to be revised and documented.

	.say "Hello."     # the environment says "Hello."
	you.say "Hello."  # the player says "Hello."
	item1.say "Hello."  # the item 'item1' says "Hello."

## enable & disable

Enables/disables a scene item. If the item is loaded (it's in the current room) the client will be notified and the change will be
noted immediately. Otherwise, it will be noted the next time a room with the item is loaded.

A disabled item is hidden and can't receive interactions.

	item1.enable  # enables a specific item (either loaded or not)
	self.disable  # disables the current interacting item (for example when picking it up)


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