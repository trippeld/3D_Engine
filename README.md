# 3D Engine (Zig + Vulkan)

A minimalistic, modern 3D engine written in **Zig** using **Vulkan**, **SDL3**, and **OpenAL Soft**.

The goal of this project is to build a **fully fledged real-time 3D engine** while keeping the implementation **as lightweight and minimal as possible**. The engine aims to use **modern graphics techniques**, **clean architecture**, and the **shortest serious implementation paths** without unnecessary abstractions, frameworks, or dependencies.

The focus is on correctness, performance, and clarity. Every system should exist only if it is required for a real engine.

The majority of this document is the **development roadmap**, listing the components required to reach the final goal.

---

# Roadmap

Current Development Step is: Lighting & Shading → Physically based shading (PBR)

## Core Platform

* [x] SDL3 window creation
* [x] Input handling (keyboard + mouse)
* [x] Relative mouse mode
* [x] High precision frame timer
* [ ] Platform abstraction cleanup
* [ ] Linux / Windows cross-platform verification

---

# Rendering (Vulkan)

## Vulkan Core

* [x] Vulkan instance creation
* [x] Surface creation via SDL3
* [x] Physical device selection
* [x] Logical device creation
* [x] Queue family selection
* [x] Swapchain creation
* [x] Swapchain image views
* [x] Command pool
* [x] Command buffers
* [x] Synchronization objects

## Rendering Setup

* [x] Dynamic rendering pipeline
* [x] Graphics pipeline creation
* [x] Shader compilation pipeline
* [x] Depth buffer
* [x] Frame submission
* [x] Swapchain recreation

## Mesh Rendering

* [x] Vertex buffer
* [x] Index buffer
* [x] Indexed drawing
* [x] Multiple draw calls
* [x] GPU device-local mesh buffers
* [x] Staging upload path
* [x] Mesh struct abstraction

## Scene Rendering

* [x] Camera system
* [x] View matrix
* [x] Projection matrix
* [x] Model transform
* [x] Multiple objects

---

# Lighting & Shading

* [x] Vertex normals
* [x] Directional light (Lambert)
* [x] Specular lighting
* [ ] Physically based shading (PBR)
* [ ] Material system
* [ ] Shader organization

---

# Mesh & Asset Pipeline

* [ ] Mesh loader (GLTF preferred)
* [ ] Mesh asset representation
* [ ] GPU mesh upload pipeline
* [ ] Texture loading
* [ ] Texture samplers
* [ ] Material definitions
* [ ] Asset management

---

# Scene System

* [ ] Scene object representation
* [ ] Transform hierarchy
* [ ] Scene submission to renderer
* [ ] Static mesh components
* [ ] Scene update pipeline

---

# Advanced Rendering

* [ ] Frustum culling
* [ ] GPU instancing
* [ ] Shadow mapping
* [ ] Environment lighting
* [ ] Skybox
* [ ] HDR rendering
* [ ] Tone mapping

---

# Performance & Memory

* [ ] GPU memory allocator
* [ ] Mesh batching
* [ ] Pipeline cache
* [ ] Descriptor management
* [ ] Multithreaded rendering preparation

---

# Audio (OpenAL Soft)

* [ ] OpenAL Soft initialization
* [ ] Audio device management
* [ ] Sound buffer loading
* [ ] Sound sources
* [ ] 3D positional audio
* [ ] Streaming audio support

---

# Engine Systems

* [ ] Logging system
* [ ] Configuration system
* [ ] Resource lifetime management
* [ ] Job system (if necessary)
* [ ] Engine runtime structure

---

# Tools

* [ ] Shader compilation pipeline
* [ ] Asset conversion tools
* [ ] Development debugging utilities

---

# Long Term Goals

* [ ] Fully functional minimal engine
* [ ] Stable scene rendering
* [ ] Lighting and materials
* [ ] Audio integration
* [ ] Example application / demo scene

---

# Design Principles

* **Minimal dependencies**
* **Modern Vulkan techniques**
* **Small, understandable systems**
* **Performance-first design**
* **No unnecessary abstraction layers**
* **Only implement systems when they are required**

The end goal is a **small, modern, fully functional 3D engine written entirely in Zig**.
