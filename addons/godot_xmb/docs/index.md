# Godot XMB Save System

Welcome to the Godot XMB Save System documentation! This system provides a beautiful, PSP/PS3-style visual save UI completely out-of-the-box, alongside a robust autosave, playtime tracker, and metadata API.

## Table of Contents
1. [Getting Started](getting_started.md)
   - Learn how to integrate the save system into your 2D or 3D games using the Save Adapter pattern.
2. [API Reference](api_reference.md)
   - Detailed documentation on the `XMBSave` singleton, covering all signals, methods, and properties.

## Features
* **Automated Screenshots**: Falls back to automatically capturing your 2D/3D viewport as the save icon if no custom icon is provided.
* **Auto Playtime Tracking**: Automatically accrues time via delta updates natively in the API and translates it to standard readable text format.
* **UI Protection**: Safely toggles background UI inputs to prevent game pausing glitches while the save menu is active.
* **Smart Contextual Menus**: Allows overwriting, deleting, copying, and creating saves fluently with fully functional mouse, keyboard, and controller support.
