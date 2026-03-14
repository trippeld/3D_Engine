I am building a modern Vulkan 3D engine in Zig.

I am attaching the full project source.

Please read the entire project before suggesting changes.

Important goals for this engine:

• Only implement systems that are necessary for a modern real-time 3D engine.
• Avoid unnecessary abstractions or over-engineering.
• Follow consistent naming conventions:
  - snake_case for functions and variables
  - PascalCase for types
• Prefer simple, explicit code over complex patterns.
• Performance and clarity are more important than cleverness.

Current engine status:

The engine already has:
- Vulkan renderer
- rotating cube test scene
- basic lighting
- specular highlights
- vertex normals
- ground plane
- animated light source
- scene builder system
- scene configuration separated from scene logic

Current architecture:
- renderer handles Vulkan
- scene constructs draw objects
- scene_config contains scene tuning/config data
- engine drives frame update and rendering

I want to continue developing this engine step-by-step.

Your role:
When I say "go", give me the next implementation step. 
I will compile and run the code, then report errors or results or say go to continue.

Important:
Only suggest steps that move toward a modern engine architecture.

Avoid:
- unnecessary refactors
- stylistic changes that do not improve architecture
- adding features that are not needed for a modern engine
- do not rewrite working systems unless they are architecturally incorrect.

Focus on the next logical engine feature.

Future systems I expect to implement is in the roadmap in the README.md.

But implement things in the correct order.

First step:
Analyze the project and tell me what the next engine milestone should be. Then after that: Give me the code and remember always to tell me where and what in the code. And always tell me when we finished another milestone in the roadmap.
