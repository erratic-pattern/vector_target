A library for vector targeted abilities in Dota 2 custom games.

![](http://giant.gfycat.com/DisgustingKindBronco.gif)

#Features
* Fullly configurable through KV
* Support for custom client-side targeting particles (as well as a default particle that mimics the built-in range finder)
* Handles both normal and quick cast settings.
* Handles shift queue (Note: there's currently some issues when the dota order queue gets maxed out)

#Installation
* Copy files from `game/scripts/vscripts` somewhere into your `dota 2 beta/game/dota_addons/*/vscripts/scripts` folder.
* Copy files from `content/` into your `dota 2 beta/content/dota_addons/*/` folder.
* Attach a copy of the [LICENSE](https://github.com/kallisti-dev/vector_target/blob/master/LICENSE) to your source code.

#Basic Setup Guide
* Add a `require` to your addons_game_mode.lua; For example, if you copied vector_target.lua into `game/dota_addons/*/scripts/vscripts/libraries/` the require would look like this:

    ```lua
    require("libraries.vector_target")
    ```

* Call `VectorTarget:Init` somewhere in your initialization code.

    ```lua
    VectorTarget:Init()
    ```

* If you plan on using the default range finder particles, you need to call `VectorTarget:Precache` in your `Precache`  function, like this:

    ```lua
    --addon_game_mode.lua
    function Precache( context ) 
        VectorTarget:Precache( context )
    end
    ```

* Finally, you need to include vector_target.js in the `<scripts>` of one of your panorama layouts. 
  The layout you choose to load the library in is mostly irrelevant, as long as you load it before abilities
  can be casted, and only load it once.

    ```xml  
    <scripts>
        <include src="file://{resources}/scripts/vector_target.js" />
    </scripts>
    ```

#KV Options
##KV File Loading
This library reads from `npc_abilities_custom.txt` and `npc_items_custom.txt` by default to get ability-specific vector targeting options. 
If you'd like options from other KV files, you can use the `kvList` option when calling `VectorTarget:Init`

  ```lua
  VectorTarget:Init({ kvList = { "my_custom_kv_file.txt", "my_custom_kv_file2.txt", myTable })
  ```

The argument is an array of "KV sources", which can be either file names or Lua tables. If you use a table as a KV source, it should
have the same format as a KV table returned by the Valve function `LoadKeyValues`.

Finally, if you want to disable KV loading, you can explicitly set `kvList` to false

##KV Options Format
For default vector targeting behavior, all you need to do is add a `VectorTarget` key to the ability's definition block.
  ```javascript
      "my_ability"
      {
          "VectorTarget"      "1"
      }
  ```    
For fine-tuning of vector targeting options, you can pass a block with various option keys:
```javascript
    "my_ability"
    {
        "VectorTarget"
        {
            "ParticleName"  "particles/my_custom_particle.vpcf"  // Use a custom particle system 
                                                                 // (set to 0 for no particle)
            
            "ControlPoints" // use custom control points for the particle
            {
                "0": "initial"  // Set CP0 to the vector's initial point (the first location clicked)
                "1": "terminal" // Set CP1 to the vector's terminal point (the second location clicked)
            }
            
            "PointOfCast"   "midpoint"  // Determines what point the caster must actually turn towards in order to 
                                        // begin the cast animation. By default this is set to "initial", which means
                                        // the caster turns towards the first point that was clicked.
                                        // Setting it to "terminal" means the caster will face the second point that
                                        // was clicked. Here we use "midpoint", which means the point of cast will be
                                        // inbetween the initial and terminal points.
                                        
            "MaxDistance"   "1000" // Sets the max distance of the vector. Currently this isn't enforced and we don't
                                   // do much with this parameter other than return it via GetMaxDistance,
                                   // but this will likely change in the future.
                                   
            "MinDistance"   "500"  // Minimum vector distance, also not fully supported yet.
        }
    }
```
#Writing Code for Vector Targeted Abilities

Once you've defined abilities to have vector targeting behavior, you can start writing code to actually handle the ability's
cast logic. When writing ability code (either through Lua abilities or through Datadriven `RunScript`), you can access the 
targeting information from a cast via special methods that the library attaches to vector targeted abilities.

##Ability Properties and Methods
Any ability that's been modified by the library will have a key named `isVectorTarget` set to true, and will have these methods:

* `:GetInitialPosition()` - The initial position as a Vector
    
* `:GetTerminalPosition()` - The terminal position as a Vector

* `:GetMidpointPosition()` - The midpoint betwen initial/terminal as a Vector

* `:GetTargetVector()` - The actual vector in the phrase "vector target", composed from the initial and terminal positions of the cast.
                     
* `:GetDirectionVector()` - The normalized target vector, indicating the direction in which the line was drawn.

* `:GetPointOfCast()` - The point, as a Vector, that the caster turns towards before beginning the cast animation.

* `:GetMaxDistance()` - The MaxDistance KV field. Currently unused by the library, but provided for ability logic.

* `:GetMinDistance()` - The MinDistance KV field. Also unsued currently.

#Real World Examples
* A Macropyre-like ability with vector targeting:
    * [Ability KV](https://github.com/kallisti-dev/WarOfExalts/blob/4aaf3c5db5ab4febd3e9ef1bd05c6529c4ca1a8a/game/dota_addons/warofexalts/scripts/npc/abilities/flameshaper_lava_wake.txt)
    * [Ability Lua](https://github.com/kallisti-dev/WarOfExalts/blob/6f62f8c5a21f0c837e9ac43bd34479230c10a76a/game/dota_addons/warofexalts/scripts/vscripts/heroes/flameshaper/flameshaper_lava_wake.lua)
 
#Advanced Topics
##ExecuteOrderFilter

This library uses `SetExecuteOrderFilter`. If you have other code that needs to run during this filter, you'll need to
set the `noOrderFilter` option when calling `VectorTarget:Init`, and then call `VectorTarget:OrderFilter` in your own custom order filter.
```lua
    VectorTarget:Init({ noOrderFilter = true })
    
    function MyExecuteOrderFilter(ctx, params)
        if not VectorTarget:OrderFilter(params) then
            return false
        end
        --insert your order filter logic here
    end
    
    GameRules:GetGameModEntity():SetExecuteOrderFilter(MyExecuteOrderFilter, {})
``` 
( As an aside, I would be very interested in working with the modding community to create a standard system for
 overloading these filter functions in a composable manner. This would go a long way in making library mode
 more readily interoptable. )
 
##Adding Vector Targeting Behavior to Abilities Dynamically
The library will "vectorify" all abilities immediately before the first time they're casted. If for some reason you want to do this before that happens,
 you will need to manually call `VectorTarget:WrapAbility`

```lua
VectorTarget:WrapAbility(myAbility)
```

There's also a shorthand `VectorTarget:WrapUnit` to do this for all abilities on a unit.
 
#Planned Improvements and to-do
* Better options for fast click-drag mode.
* Support various combinations of unit-targeting and point-targeting, for example HoN's "Vector Entity" target type.
* Add more built-in particles for area/cone abilities, and wide abilities.
* Add more variables for the `ControlPoints` KV blocks.
* Properly handling %variables from `AbilitySpecial` in VectorTarget KV block.
* Enforce and fully support `MaxDistance` and `MinDistance`. Which includes:
    *Options for specifying the localization string for "invalid cast distance" error messages.
    *Add `ControlPoint` variables for range finders to properly show valid/invalid distances
    *Add level scaling format, i.e.  `"MaxDistance"  "500 600 700 800"`
  
#Feedback, Suggestions, Contributions

I am very interested in hearing your ideas for improving this library. Plese contact me at the email mentioned above
if you have an idea or suggestion, and please submit a pull request to our github repo if you have a modification
that would improve the library.
