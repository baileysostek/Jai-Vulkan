<!-- <p align="center"><img src="https://github.com/baileysostek/Jai-Vulkan/blob/main/github/cadmium_games.png" alt="Cadmium Games" width="512"/></p> -->

# <p align="center"> Jai-Vulkan </p>
Hello! I was graciously added to the Jai-Beta and I fully intend to switch over the development of my Game, Guac-A-Mole to use Jai instead of Java. 

I am using this repository as a public documentation of my experience learning Vulkan and also the inner-workings of Jai on a more serious project than my first project which was a minesweeper clone called Jai-Mines. 

I have primarily been using the resource https://vulkan-tutorial.com/ to research and learn the Vulkan Graphics API and am currently up to the "Uniform Buffers" section. I intend for this resource to grow as a standalone Jai-Module which will be used as the base for all of my future games, which I intend to develop in Jai.

This project will slowly grow and develop over time to replace my Java-based game engine, Reactor. 


## Todo
[] Create Mesh loaded to load complex models
[] Create ShaderManager which can automatically reload or hot-swap shaders during development
[] ImGUI + Immediate Mode Graphics layers.
[] Learn about differed rendering in Vulkan.
[] PBR shader for Vulkan
[] Re-Implement game logic for Guac-A-Mole

LOTS more TODO, I intend for this repository to have feature parody with my Java-based implementation of Reactor. 

## <p align="center"> Test </p>
<p align="center"><img src="https://github.com/baileysostek/Jai-Vulkan/blob/main/github/reactor_5-9-23.gif" alt="Jai-Vulkan"/></p>

## <p align="center"> Timeline </p>

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
