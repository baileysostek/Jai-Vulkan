<!-- <p align="center"><img src="https://github.com/baileysostek/Jai-Vulkan/blob/main/github/cadmium_games.png" alt="Cadmium Games" width="512"/></p> -->

# <p align="center"> Jai-Vulkan </p>
Hello! I was graciously added to the Jai-Beta and I fully intend to switch over the development of my Game, Guac-A-Mole to use Jai instead of Java. 

I am using this repository as a public documentation of my experience learning Vulkan and also the inner-workings of Jai on a more serious project than my first project which was a minesweeper clone called Jai-Mines. 

I have primarily been using the resource https://vulkan-tutorial.com/ to research and learn the Vulkan Graphics API and am currently up to the "Uniform Buffers" section. I intend for this resource to grow as a standalone Jai-Module which will be used as the base for all of my future games, which I intend to develop in Jai.

This project will slowly grow and develop over time to replace my Java-based game engine, Reactor. 


## Todo
[] SSBO implementation to hold position data for our entities. 
[] ModelLoader file to cache models loaded by the project with #run directives to bake assets into the executable to reduce the need to load from disk at startup.
[] Create Mesh loaded to load complex models
[] Create ShaderManager which can automatically reload or hot-swap shaders during development
[] ImGUI + Immediate Mode Graphics layers.
[] Learn about differed rendering in Vulkan.
[] PBR shader for Vulkan
[] Re-Implement game logic for Guac-A-Mole

LOTS more TODO, I intend for this repository to have feature parody with my Java-based implementation of Reactor. 

## <p align="center"> Current Progress </p>
<p align="center"><blockquote class="imgur-embed-pub" lang="en"><a href="https://imgur.com/a/eH4DZ54">View post on imgur.com</a></blockquote></p>

## <p align="center"> Timeline </p>

#### May - 20 - 2023
* Changed Camera rotation to be correct for First Person Perspective with Y,X,Z rotation ordering.
* Refactored Keyboard class and Camera class to hold references to the keyboard state and active camera respectively. Now this information does not need to be passed around from the core reactor.jai file to the rest of the project.  


#### May - 19 - 2023
* Re-Implemented Camera class to be more correct than the way that I was representing cameras before. Once I better understand module scopes the various parts of Reactor will probably be re-implemented an additional time to scope the variables currently in reactor.jai to the CameraManager module. 

* Move around with W,A,S,D,Q,E 

#### May - 14 - 2023
* Fixed issue with projection matrix passed in Uniform Buffer Object to vertex shader for perspective projection. Now we have perspective projection and we can continue on to render multiple objects on the screen at a time. Not sure best way to do this, Uniform Buffer Array maybe?


#### May - 09 - 2023
* Created README and organized repo to be more presentable.

* Fixed issue with vkAllocateDescriptorSets causing a nasty crash. The sollution was to not try to initialize all descriptor sets at once, and instead Allocate them one after another in a loop. 

* Started to get Uniform information to transfer to the current process and be able to augment the rendering of the quad with uniforms.
```
vkAllocateDescriptorSets(device, *alloc_info, descriptor_sets.data)
```
Fix:
```
for 0 .. MAX_FRAMES_IN_FLIGHT - 1 {
     vkAllocateDescriptorSets(device, *alloc_info, *descriptor_sets[it])
}
```

TODO: 
* Strange Issue with the matrices used for view and projection, I think it has something to do with the left-handedness vs right-handedness of some of the Math Matrix functions maybe?? I don't really know 

#### May - 07 - 2023
* Start of crating Vertex Buffers.
* Finished the Vertex Buffers Chapter of vulkan-tutorial.com
TODO: 
* Allocating descriptor sets crashes in a bad way internally and provides little insight as to what the problem is. I have isolated the crash to the "vkAllocateDescriptorSets" Function. here is what the crash looks like.
```
Printing the stack trace:
handle_exception                  C:\Program Files\jai\modules\Runtime_Support_Crash_Handler.jai:363
... (skipping OS-internal procedures)
unknown                           unknown:0
unknown                           unknown:0
unknown                           unknown:0
unknown                           unknown:0
unknown                           unknown:0
unknown                           unknown:0
unknown                           unknown:0
```

#### May - 04 - 2023
* Finished Swapchain creation code. 

#### May - 02 - 2023
* First Triangle is able to be rendered on the screen!

#### April - 30 - 2023
* Ability to Create Vulkan Window Surface for Windows.
* Vulkan Validation layers.

#### April - 29 - 2023
* Initial commit of this repository.
* Window creation code.
* Creating a Vulkan Instance.
