

# Instruction reference

|      Command      |                  Description                  |   Sintaxis                                                                            |
|:-----------------:|:--------------------------------------------- |:------------------------------------------------------------------------------------- |
| **load_room**     | Loads a new room.                             | `            .load_room    <room_id>                                                ` |
| **enable_input**  | Enables input and show controls.              | `            .enable_input                                                          ` |
| **disable_input** | Disable input and hides controls.             | `            .disable_input                                                         ` |
| **wait**          | Waits `delay` seconds.                        | `            .wait         <delay> [skippable=true\|false]                          ` |
| **say**           | The environment or an item says something.    | ` [<subject>].say          <speech> [skippable=true\|false]  [duration=<delay>]     ` |
| **walk**          | Player or item walks to position.             | `   <subject>.walk         to=<target_name>                                         ` |
| **set**           | Sets the value of a global variable.          | `            .set          <var_name>=<expression...>                               ` |
| **enable**        | Enable a scene item (loaded or not).          | `   <subject>.enable                                                                ` |
| **disable**       | Disable a scene item (loaded or not).         | `   <subject>.disable                                                               ` |
| **add**           | Increments an inventory item's count.         | `            .add          <inv_name>                                               ` |
| **remove**        | Decrements an inventory item's count.         | `            .remove       <inv_name>                                               ` |
| **end**           | Ends the game.                                | `            .end                                                                   ` |
