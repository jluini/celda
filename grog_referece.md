

           .load_room        <room_name>: String
           .load_actor       <actor_name>: String
           .enable_input
           .disable_input
           .wait             <delay>: float            [skippable=true|false]
 [subject] .say              <speech>: String          [skippable=true|false] [duration=float]
  subject  .walk             to=<target_name>:String
           .end
           .set              <var_name>: String        value: bool
  subject  .enable
  subject  .disable

