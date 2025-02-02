---
layout: post
title: "C# roguelike, devlog 7: Raylib and ImGui"
image: devlog7.png
---

### Introduction
---

<!--summary-->

It's time to bring the project into the third dimension by using the [raylib](https://www.raylib.com/){:target="_blank"} library.

Raylib is written in C, but has bindings for a whole bunch of programming languages. The bindings for C# is [Raylib-cs](https://github.com/ChrisDill/Raylib-cs){:target="_blank"}. For documentation on how to use the library we can check the [C# usage examples](https://github.com/ChrisDill/Raylib-cs/tree/master/Examples){:target="_blank"}, the [Raylib Cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html){:target="_blank"} and the [Raymath Cheatsheet](https://www.raylib.com/cheatsheet/raymath_cheatsheet.html){:target="_blank"}.

In addition to raylib I'll add [Dear ImGui](https://github.com/ocornut/imgui){:target="_blank"} and use it first and foremost for debugging but perhaps also to build some tools later on.
[ImGui.NET](https://github.com/ImGuiNET/ImGui.NET){:target="_blank"} is the C# wrapper for ImGui and to get ImGui to use raylib for rendering I'll also add the [rlImGui-cs](https://github.com/raylib-extras/rlImGui-cs){:target="_blank"} library.

<!--/summary-->

### Implementation
---

Here I'll setup a basic raylib game loop and render the map and player using some simple geometric shapes. I'll also add a little minimap and a debug mode that can be accessed by pressing *Tab*. When the debug mode is active ImGui is visible.

{% include folder_tree.html root="Roguelike" content="+Makefile,Roguelike.csproj,src|BspNode.cs|BspTree.cs|Corridor.cs|Game.cs|+LogEntry.cs|+Logger.cs|Map.cs|PathGraph.cs|Rand.cs|Room.cs|Vec2.cs" %}

Adding Raylib and ImGui to the project is very easy by using the NuGet package manager:

{% include bash_command.html bash_dir="~/Roguelike" bash_command="dotnet add package Raylib-cs" %}

{% include bash_command.html bash_dir="~/Roguelike" bash_command="dotnet add package ImGui.NET" %}

{% include bash_command.html bash_dir="~/Roguelike" bash_command="dotnet add package rlImgui-cs" %}

When working with Raylib we'll use pointers when reading stuff like texture data from memory. To allow the use of pointers in C# *[AllowUnsafeBlocks](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/language#allowunsafeblocks){:target="_blank"}* needs to be set to true in the .csproj file, additionally any method using pointers needs to include the *[unsafe](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/unsafe){:target="_blank"}* keyword.

<div class="block-title">Roguelike.csproj:</div>

```diff
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
+   <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <Nullable>enable</Nullable>
  </PropertyGroup>

+ <ItemGroup>
+   <PackageReference Include="ImGui.NET" Version="1.90.8.1" />
+   <PackageReference Include="Raylib-cs" Version="6.0.0" />
+   <PackageReference Include="rlImgui-cs" Version="2.0.3" />
+ </ItemGroup>

</Project>
```

It's probably a good time now to add a Makefile to the project. Even though the command for running a dotnet project is very short I prefer to have a makefile and use the command `make run` instead.

<div class="block-title">Makefile:</div>

```make
build:
	dotnet publish -o builds/ -r linux-x64 -p:PublishSingleFile=true --self-contained true
	rm builds/*.pdb

build-win:
	dotnet publish -o builds/ -r win-x64 -p:PublishSingleFile=true --self-contained true
	rm builds/*.pdb

run:
	dotnet run

clean:
	dotnet clean
```

<div class="block-title">Logger.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Logs messages and errors for debugging.
/// </summary>
static class Logger
{
    public static List<LogEntry> log { get; private set; } = new List<LogEntry>();

    // Add message to the log
    public static void Log(string message)
    {
        log.Add(new LogEntry(message));
    }
    
    // Add error message to the log
    public static void Err(string message)
    {
        log.Add(new LogEntry(message, error: true));
    }

}
```

<div class="block-title">LogEntry.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// A entry in the Logger.
/// </summary>
public class LogEntry
{
    public readonly string message;
    public readonly bool error;

    public LogEntry(string message, bool error = false)
    {
        this.message = message;
        this.error = error;
    }
}

```

<div class="block-title">BspTree.cs:</div>

```diff
    // Print info for a given node
    private void NodeInfo(BspNode node)
    {
-       Console.WriteLine("Node (" + node.id.ToString() + "), parent: " + (node.parent != null ? node.parent.id : "null") + ", sibling: " + (node.GetSibling() != null ? node.GetSibling().id : "null") + ", children[0]: " + (node.children[0] != null ? node.children[0].id : "null") + ", children[1]: " + (node.children[1] != null ? node.children[1].id : "null"));
+       Logger.Log("Node (" + node.id.ToString() + "), parent: " + (node.parent != null ? node.parent.id : "null") + ", sibling: " + (node.GetSibling() != null ? node.GetSibling().id : "null") + ", children[0]: " + (node.children[0] != null ? node.children[0].id : "null") + ", children[1]: " + (node.children[1] != null ? node.children[1].id : "null"));
    }
```


<div class="block-title">Player.cs:</div>

```diff
+   using Raylib_cs;
+   using System.Numerics;

    ...

-   private int visionRange = 16;
+   private int visionRange = 48;

    public Player()
    {
        Spawn();
        Fov();
    }

+   public void Render3D()
+   {
+       Raylib.DrawSphereWires(new Vector3((float)x + 0.5f, 0.5f, (float)y + 0.5f), 0.5f, 4, 4, Color.Pink);
+   }

    ...
```

<div class="block-title">Map.cs:</div>

```diff
+   using Raylib_cs;
+   using System.Numerics;

    ...

    // Map data
    public BspTree tree { get; private set; }
    private bool?[,] map;
    private List<int> mapSeen = new List<int>();
    private List<int> mapVisible = new List<int>();
    public readonly PathGraph pathGraph;
+   private List<int> doors = new List<int>();

    ...

    // Add a door to the map
    public void AddDoor(int x, int y)
    {
        int coord = MapCoord(x, y);
        if (map[x, y] == true)
        { 
+           doors.Add(coord);
            blocksLight[coord] = 12;
        }
    }

+   // Returns true if a given location contains a door
+   public bool GetDoor(int coord)
+   {
+       return doors.Contains(coord);
+   }

    ...

-   // Render map as ascii characters
-   public void Render() {
-       for (int y = 0; y < height; y++)
-       {
-           for (int x = 0; x < width; x++)
-           {
-               int coord = MapCoord(x, y);
-               char tileChar = '.';
-               Console.ForegroundColor = ConsoleColor.White;

-               // Render player
-               if (Game.player.x == x && Game.player.y == y) { tileChar = '@'; }

-               // Check if location has been seen
-               else if (GetSeen(coord))
-               {
-                   if (map[x, y] == true)
-                   {
-                       tileChar = ' ';
-                   }
-                   else if (map[x, y] == false)
-                   {
-                       tileChar = '#';
-                   }
-                   
-                   // Visualize light intensity
-                   if (GetVisible(coord))
-                   {
-                       int lightIntensity = GetLightIntensity(x, y);
-                       if (lightIntensity > 16) { Console.BackgroundColor = ConsoleColor.Yellow; }
-                       else if (lightIntensity > 8) { Console.BackgroundColor = ConsoleColor.Gray; }
-                       else if (lightIntensity > 0) { Console.BackgroundColor = ConsoleColor.DarkGray; }
-                       else { Console.BackgroundColor = ConsoleColor.Black; }
-                   }
-               }

-               // Fade out non-visible locations
-               if (!GetVisible(coord)) { Console.ForegroundColor = ConsoleColor.DarkGray; }

-               // Write char to console
-               Console.Write(tileChar);
-               Console.ResetColor();
-           }
-           
-           // Go to next line
-           Console.Write(Environment.NewLine);
-       }
-   }

+   // Render map
+   public void Render3D()
+   {
+       for (int y = 0; y < height; y++)
+       {
+           for (int x = 0; x < width; x++)
+           {
+               if (map[x, y] != null)
+               {
+                   // Get the coord for the current location
+                   int coord = MapCoord(x, y);
+                   
+                   // Check if location has been seen
+                   if (GetSeen(coord) || Game.debugMode)
+                   {
+                       Color color = Color.LightGray;
+                       
+                       // Check if location is visible
+                       if (GetVisible(coord)) {
+                           
+                           // Check if the current location is open space
+                           if (map[x, y] == true) {
+                               
+                               // Set floor color
+                               color = Color.Green;
+                               
+                               // Visualize light intensity
+                               int lightIntensity = GetLightIntensity(x, y);
+                               Color lightColor = Color.Gray;
+                               if (lightIntensity > 16) { lightColor = Color.Yellow; }
+                               else if (lightIntensity > 8) { lightColor = new Color(200, 200, 0, 255);; }
+                               else if (lightIntensity > 0) { lightColor = new Color(150, 150, 0, 255);; }
+                               Raylib.DrawSphereEx(new Vector3(x + 0.5f, 0.5f, y + 0.5f), 0.15f, 4, 4, lightColor);
+                               
+                               // Check if the current location contains a door
+                               if (GetDoor(coord))
+                               {
+                                   // Set door color
+                                   color = Color.Blue;
+                               }
+                           }
+                           
+                           // If not then the current location is a wall
+                           else 
+                           {
+                               // Set wall color
+                               color = Color.Red;
+                           }
+                       }
+                       
+                       // Draw floor
+                       Raylib.DrawCubeWiresV(new Vector3(x + 0.5f, -0.5f, y + 0.5f), new Vector3(1.0f, 1.0f, 1.0f), color);
+                       
+                       // Draw wall
+                       if (map[x, y] == false) {
+                           Raylib.DrawCubeWiresV(new Vector3(x + 0.5f, 0.5f, y + 0.5f), new Vector3(1.0f, 1.0f, 1.0f), color);
+                       }
+                       
+                       // Draw player indicator
+                       if (Game.player.x == x && Game.player.y == y)
+                       {
+                           Raylib.DrawPlane(new Vector3(x + 0.5f, 0.0f, y + 0.5f), new Vector2(1.0f, 1.0f), Color.Yellow);
+                       }
+                       
+                       // Draw door indicator
+                       else if (GetDoor(coord))
+                       {
+                           Raylib.DrawPlane(new Vector3(x + 0.5f, 0.0f, y + 0.5f), new Vector2(1.0f, 1.0f), color);
+                       }
+                   }
+               }
+           }
+       }
+   }

+   // Render minimap
+   public void Render2D()
+   {
+       int cellSize = 6;
+       int xOffset = Raylib.GetRenderWidth() - (width * cellSize);
+       Raylib.DrawRectangle(xOffset, 0, width * cellSize, height * cellSize, Color.DarkGray);
+       for (int y = 0; y < height; y++)
+       {
+           for (int x = 0; x < width; x++)
+           {
+               if (map[x, y] != null)
+               {
+                   
+                   // Show player position on minimap
+                   if (Game.player.x == x && Game.player.y == y)
+                   {
+                       Raylib.DrawRectangle(xOffset + (x * cellSize), y * cellSize, cellSize, cellSize, Color.Yellow);
+                   }
+                   
+                   else
+                   {
+                       // Get the coord for the current location
+                       int coord = MapCoord(x, y);
+                       
+                       // Check if location has been seen
+                       if (GetSeen(coord) || Game.debugMode)
+                       {
+                           Color color = Color.LightGray;
+                           
+                           // Check if location is visible
+                           if (GetVisible(coord)) {
+                               
+                               // Check if location is open space
+                               if (map[x, y] == true) {
+                                   
+                                   // Set floor color
+                                   color = Color.Green;
+                                   
+                                   // Check if the current location contains a door
+                                   if (GetDoor(coord))
+                                   {
+                                       // Set door color
+                                       color = Color.Blue;
+                                   }
+                               }
+                               
+                               // If not then the current location is a wall
+                               else 
+                               {
+                                   // Set wall color
+                                   color = Color.Red;
+                               }
+                           }
+                           
+                           // Draw minimap cell
+                           Raylib.DrawRectangleLines(xOffset + (x * cellSize), y * cellSize, cellSize, cellSize, color);
+                       }
+                   }
+               }
+           }
+       }
+   }

    ...
```

<div class="block-title">Game.cs:</div>

```csharp
using Raylib_cs;
using rlImGui_cs;
using ImGuiNET;
using System.Numerics;

namespace Roguelike;

static class Game
{
    private static bool isRunning = true;
    public static bool debugMode { get; private set; } = false;
    public static Map map { get; private set; }
    public static Player player { get; private set; }
    private static Camera3D camera;

    // Program entry point
    static void Main(string[] args)
    {
        Init();
        Run();
        Exit();
    }

    // Initialize
    private static void Init()
    {
        // Raylib & Imgui initialization
        Raylib.InitWindow(1280, 720, "Roguelike");
        Raylib.SetTargetFPS(30);
        rlImGui.Setup(true);

        // Create new objects
        map = new Map(96, 48);
        player = new Player();
        
        // Camera setup
        camera.Position = Vector3.Zero;
        camera.Target = Vector3.Zero;
        camera.Up = Vector3.UnitY;
        camera.FovY = 45.0f;
        camera.Projection = CameraProjection.Perspective;
    }

    // Main game loop
    private static void Run()
    {
        while (!Raylib.WindowShouldClose())
        {
            Input();
            Update();
            Render();
        }
    }

    // Exit game
    private static void Exit()
    {
        rlImGui.Shutdown();
        Raylib.CloseWindow();
    }

    // Handle user input
    private static void Input()
    {
        // System
        if (Raylib.IsKeyPressed(KeyboardKey.Tab)) { debugMode = !debugMode; }
        if (Raylib.IsKeyPressed(KeyboardKey.F)) { Raylib.ToggleFullscreen(); }
        
        // Player movement
        if (Raylib.IsKeyPressed(KeyboardKey.Up)) { player.MoveUp(); }
        else if (Raylib.IsKeyPressed(KeyboardKey.Down)) { player.MoveDown(); }
        else if (Raylib.IsKeyPressed(KeyboardKey.Left)) { player.MoveLeft(); }
        else if (Raylib.IsKeyPressed(KeyboardKey.Right)) { player.MoveRight(); }
    }

    // Update things in the game
    private static void Update()
    {
        float deltaTime = Raylib.GetFrameTime();

        // Camera
        Vector3 cameraTargetGoal = new Vector3((float)player.x, 0f, (float)player.y);
        camera.Target = Raymath.Vector3Distance(camera.Target, cameraTargetGoal) > 0.1f ? Raymath.Vector3Lerp(camera.Target, cameraTargetGoal, 0.05f) : camera.Target;
        camera.Position = camera.Target + new Vector3(0f, 16.0f, 12.0f);
    }

    // Render things on screen
    private static void Render()
    {
        // Start render
        Raylib.BeginDrawing();

        // Set background color
        Raylib.ClearBackground(Color.Black);

        // 3D rendering
        Raylib.BeginMode3D(camera);
        if (debugMode) { Raylib.DrawGrid(300, 1.0f); }
        map.Render3D();
        player.Render3D();
        Raylib.EndMode3D();

        // 2D rendering
        map.Render2D();
        Raylib.DrawFPS(2,2);
        Raylib.DrawText("POSITION: " + player.x.ToString() + "x" + player.y.ToString(), 2, Raylib.GetRenderHeight() - 16, 16, Color.White);
        
        // 2D rendering (debug mode)
        if (debugMode) {
            Raylib.DrawText("DEBUG MODE", 2, 20, 16, Color.White);
            RenderImGui();
        }

        // End render
        Raylib.EndDrawing();
    }

    // Render ImGui
    private static void RenderImGui()
    {
        // Start ImGui
        rlImGui.Begin();

        //ImGui.ShowDemoWindow();
        
        // Debug window
        if (ImGui.Begin("Debug window"))
        {
            ImGui.Text("Log:");
            ImGui.BeginChild("Log");
            for (int i = 0; i < Logger.log.Count; i++)
            {
                LogEntry logEntry = Logger.log[i];
                ImGui.Text(logEntry.message);
            }
            ImGui.EndChild();
        }

        // End ImGui
        ImGui.End();
        rlImGui.End();
    }
}
```

### Conclusion
---

And there we have a 3D version of the project. Move around with the arrow keys, press *F* for fullscreen or press *Tab* to enter debug mode. We can also use the Makefile now to run and build the project.

{% include bash_command.html bash_command="make run" bash_dir="~/Roguelike" %}

[![screenshot](/img/screenshot_2024-06-09-132645.png)](/img/screenshot_2024-06-09-132645.png){:target="_blank"}

Here's a short video of the result: [youtu.be/4X8wz6Xd8NU](https://youtu.be/4X8wz6Xd8NU){:target="_blank"}

Download the source code: [roguelike-devlog7.zip](/files/roguelike-devlog7.zip){:target="_blank"}

Find the project on GitHub: [lzzrhx/roguelike](https://github.com/lzzrhx/roguelike){:target="_blank"}
