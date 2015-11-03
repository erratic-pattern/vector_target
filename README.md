A library for vector targeted abilities in Dota 2 custom games.

![](http://gfycat.com/DisgustingKindBronco)

#Table of Contents
* [Features](#features)
* [Installation](#installation)
* [Basic Setup Guide](#basic-setup-guide)
* [KV Options](#kv-options)
    * [Custom Targeting Particles](#custom-targeting-particles)
    * ["Point of Cast"](#point-of-cast)
    * [Minimum and Maximum Distance](#minimum-and-maximum-distance)
* [Writing Ability Code](#writing-ability-code)
    * [Ability Properties and Methods](#ability-properties-and-methods)
* [Code Examples](#code-examples)
* [Advanced Topics](#advanced-topics)
    * [KV Loading (from File or Table)](#kv-loading-from-file-or-table)
    * [ExecuteOrderFilter](#executeorderfilter)
    * [Adding Vector Targeting Behavior to Abilities Dynamically](#adding-vector-targeting-behavior-to-abilities-dynamically)
* [Planned Improvements and to-do](#planned-improvements-and-to-do)
* [Feedback, Suggestions, Contributions](#feedback-suggestions-contributions)

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
For configuration of individual ability behavior, we use custom KV options. Just add these options directly to your existing ability KV, in either `npc_abilities_custom.txt` or `npc_items_custom.txt`. See the [advanced KV loading](#kv-loading-from-file-or-table) section if you want more control over how KV options are loaded.

For default vector targeting behavior, all you need to do is add a non-zero `VectorTarget` key to the ability's definition block.

  ```javascript
      "my_ability"
      {
          "VectorTarget"      "1"
      }
  ```    

For fine-tuning of vector targeting options, you can pass a block with various option keys.

```javascript
    "my_ability"
    {
        "VectorTarget"
        {
            "ParticleName"  "particles/my_custom_particle.vpcf"
            "PointOfCast"   "midpoint"  
            "MaxDistance"   "1000" 
            "MinDistance"   "500"  
        }
    }
```

The following sections cover these options in detail.

###Custom Targeting Particles

You can choose a custom particle system to use instead of the default range finder

```javascript
            "ParticleName"  "particles/my_custom_particle.vpcf"
```

Since useful targeting indicators are for casual scrubs that play League of Legends and have no business being in Hardcore Games™, you can set this option to "0" to disable any kind of range finder.

You can also feed in custom control point data to your particle system.

```javascript
            "ControlPoints" // use custom control points for the particle
            {
                "0" "initial"  // Set CP0 to the vector's initial point (the first location clicked)
                "1" "terminal" // Set CP1 to the vector's terminal point (the second location clicked)
            }
```

###"Point of Cast"

While conceptually a vector targeted ability targets a vector, in the Dota engine it is just a normal point targeted ability. As such, there is a point that the unit must be in range of and turn towards before beginning the cast animation. By default, that point is chosen to be the first point clicked, but you can choose other points as well. This point is called the "point of cast" to avoid confusion with the term "cast point", which has a completely different meaning in Dota terminology.

Using `midpoint` will make the caster turn towards the midpoint of the vector (treating it as a line segment)

```javascript
    "PointOfCast" "midpoint"
```

Using `terminal` will make the caster turn towards the terminal position (second point that was clicked)

```javascript
    "PointOfCast" "terminal"
```

For complete flexibility, you can instead override the method `GetPointOfCast` on your Lua ability, returning an exact Vector to use.

###Minimum and Maximum Distance

```javascript
    "MaxDistance"   "1000" // Sets the max distance of the vector. Currently this isn't enforced and we don't
                           // do much with this parameter other than return it via GetMaxDistance,
                           // but this will likely change in the future.
                           
    "MinDistance"   "500"  // Minimum vector distance, also not fully supported yet.
```

#Writing Ability Code

Once you've defined abilities to have vector targeting behavior, you can start writing code to actually handle the ability's
cast logic. When writing ability code you can access the targeting information from a cast via special methods that the library attaches to vector targeted abilities.

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

#Code Examples
* A Macropyre-like ability with vector targeting:
    * [Ability KV](https://github.com/kallisti-dev/WarOfExalts/blob/4aaf3c5db5ab4febd3e9ef1bd05c6529c4ca1a8a/game/dota_addons/warofexalts/scripts/npc/abilities/flameshaper_lava_wake.txt)
    * [Ability Lua](https://github.com/kallisti-dev/WarOfExalts/blob/6f62f8c5a21f0c837e9ac43bd34479230c10a76a/game/dota_addons/warofexalts/scripts/vscripts/heroes/flameshaper/flameshaper_lava_wake.lua)
 
#Advanced Topics
##KV Loading (From File or Table)
If you have a sophisticated custom KV setup for your addon or would simply prefer seperating dota-specific KV stuff from vector-target-specific KV stuff, you can use the `kvList` option when calling `VectorTarget:Init` to load KV options from other sources.

  ```lua
  VectorTarget:Init({
    kvList = { "my_custom_kv_file.txt", "my_custom_kv_file2.txt", myTable } 
  })
  ```

`kvList` is an array of "KV sources", which can be either file names or Lua tables. If you use a table as a KV source, it should have the same format as a KV table returned by the Valve function `LoadKeyValues`. If you want to disable automatic KV loading, you can explicitly set `kvList` to false


##ExecuteOrderFilter

This library uses `SetExecuteOrderFilter`. If you have other code that needs to run during this filter, you'll need to
set the `noOrderFilter` option when calling `VectorTarget:Init`, and then call `VectorTarget:OrderFilter` in your own custom order filter.

```lua
    VectorTarget:Init({ noOrderFilter = true })
    
    function MyExecuteOrderFilter(ctx, params)
        --insert your order filter logic here
        return VectorTarget:OrderFilter(params)
    end
    
    GameRules:GetGameModEntity():SetExecuteOrderFilter(MyExecuteOrderFilter, {})
```

This is a simple example of what your custom filter might look like, but it could be written differently. The only requirement is that your custom order filter MUST `return false` whenever `VectorTarget:OrderFilter` returns false. This is because `VectorTarget:OrderFilter` needs to force the engine to ignore the initial cast order of a vector targeted ability.

**A call to action for the modding community**: I would be very interested in working with the modding community
to create a standard system for overloading these filter functions in a composable manner, perhaps something incorporated
into barebones, or a fork of barebones. This would go a long way in making library code more readily interoptable.
 
##Adding Vector Targeting Behavior to Abilities Dynamically
The library will "vectorify" all abilities immediately before the first time they're casted. If for some reason you want to do it earlier, you will need to manually call `VectorTarget:WrapAbility`

```lua
VectorTarget:WrapAbility(myAbility)
```

After the first `VectorTarget:WrapAbility` call, further calls will have no additional effect. So it's safe to call this function multiple times on the same ability.

`VectorTarget:WrapUnit` can be used to apply this wrapper to all the current abilities of a unit/NPC.
 
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

Plese contact [kallisti.dev@gmail.com](mailto:kallisti.dev@gmail.com) if you have an idea or suggestion, and please submit a pull request to the github repo if you have a modification that would improve the library.
