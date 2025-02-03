---
layout: post
title: "C# roguelike, devlog 6: Shadowcasting"
image: devlog6
---

<!--![devlog](/img/devlog6.gif){:target="_blank"}-->

### Introduction
---

<!--summary-->

Next up is adding a field-of-view algorithm. Here I thought I would try to implement the [Symmetric Shadowcasting](https://www.albertford.com/shadowcasting/){:target="_blank"} algorithm by Albert Ford. He explains Symmetric Shadowcasting very well in the video presentation [Vision Visualized](https://youtu.be/y1zkrTcNJbc){:target="_blank"}.

Another approach to shadowcasting can be found in the blog post [What the Hero Sees: Field-of-View for Roguelikes](https://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/){:target="_blank"} by [Bob Nystrom](https://x.com/munificentbob){:target="_blank"}

For further reading on field-of-view algorithms check out the post (as referenced by Albert Ford) [Roguelike Vision Algorithms](http://www.adammil.net/blog/v125_Roguelike_Vision_Algorithms.html){:target="_blank"} by Adam Milazzo.

<!--/summary-->

### Implementation
---

In addition to the shadowcasting algorithm I'll also add a player character that can move around on the map with the arrow keys, and rewrite the *Game* class to add a basic game loop.

I'll create a new static *Shadowcast* class, and it'll contain the Symmetric Shadowcast algorithm. See the link above for more information on how it works.

I'll quickly make a *Player* class too, and add some basic functionality like spawning on the *Map* and moving around, plus add calls to the static *Shadowcast* class to check what's visible from the player's position.

In the *Map* class I'll add some methods for checking if a location blocks vision, like a wall, if a location has has been seen by the player before at some point and a method to check if a given loction is currently visible. Locations that have been seen are stored in a list, and locations that are currently visible are stored in a seperate list.

In *Game* I'll add a super simple game loop that get's user input and renders text in the console.

{% include folder_tree.html root="Roguelike" content="Roguelike.csproj,src|BspNode.cs|BspTree.cs|Corridor.cs|Game.cs|Map.cs|PathGraph.cs|+Player.cs|Rand.cs|Room.cs|+ShadowCast.cs|Vec2.cs" %}

<div class="block-title">Game.cs:</div>

```csharp
namespace Roguelike;

static class Game
{
    private static bool isRunning = true;
    public static Map map { get; private set; }
    public static Player player { get; private set; }

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
        map = new Map(96, 48);
        player = new Player();
    }

    // Main game loop
    private static void Run()
    {
        // Setup console
        Console.CursorVisible = false;
        Console.ResetColor();
        Console.Clear();

        while (isRunning)
        {
            Render();
            Input();
        }

        // Reset console back to normal
        Console.CursorVisible = true;
        Console.ResetColor();
        Console.Clear();
    }

    // Exit game
    private static void Exit()
    {
        Console.WriteLine("Quitting..");
    }

    // Handle user input
    private static void Input()
    {
        // Loop until valid input is given
        bool validKey = false;
        while (!validKey)
        {
            // Wait for and get key input from user
            ConsoleKeyInfo key = Console.ReadKey(true);

            // Check if key was valid and process input
            validKey = ProcessInput(key);
        }
    }

    // Check if the pressed key was valid and process input
    private static bool ProcessInput(ConsoleKeyInfo key)
    {
            switch (key.Key)
            {
                case ConsoleKey.UpArrow:
                    return player.MoveUp();
                case ConsoleKey.DownArrow:
                    return player.MoveDown();
                case ConsoleKey.LeftArrow:
                    return player.MoveLeft();
                case ConsoleKey.RightArrow:
                    return player.MoveRight();
                case ConsoleKey.Escape:
                    isRunning = false;
                    return true;
            }

            return false;
    }

    // Render things on screen
    private static void Render()
    {
        // NOTE: This is a very inefficient way to clear the console that will result in heavy flickering, but it's just a temporary sollution.
        Console.Clear();

        // A slightly better alternative to Console.Clear() could perhaps be something like:
        // string blank = new String(' ', 96);
        // Console.SetCursorPosition(0, 0);
        // for (int i = 0; i < 48; i++)
        // {
        //     Console.Write(blank + Environment.NewLine);
        // }
        // Console.SetCursorPosition(0, 0);

        map.Render();
    }
}
```

<div class="block-title">Map.cs:</div>

```diff
    ...

    // Map data
    public BspTree tree { get; private set; }
    private bool?[,] map;
+   private List<int> mapSeen = new List<int>();
+   private List<int> mapVisible = new List<int>();
    public readonly PathGraph pathGraph;

    // Constructor
    public Map(int width, int height)
    {
        this.width = width;
        this.height = height;
        this.map = new bool?[width, height];
        this.pathGraph = new PathGraph(this);
        this.tree = new BspTree(this, width, height);
        BuildMap();
-       Render();
    }

    public int MapCoord(int x, int y)
    {
        return (width * y) + x;
    }

    // Converts mapcoord to Vec2
    public Vec2 MapCoordReverse(int coord)
    {
        return new Vec2(coord % width, coord / width);
    }

+   // Returns true if a given Vec2 location is within the map bounds
+   public bool InBounds(Vec2 location)
+   {
+       if (location.x >= 0 && location.x < width && location.y >= 0 && location.y < height) { return true; }
+       return false;
+   }

+   // Returns true if a given Vec2 location blocks vision
+   public bool GetVisionBlocking(Vec2 location)
+   {
+       return InBounds(location) ? map[location.x, location.y] == false : true;
+   }

+   // Clear the list of visible locations
+   public void ClearVisible()
+   {
+       mapVisible.Clear();
+   }

+   // Set a given Vec2 location to visible   
+   public void SetVisible(Vec2 location)
+   {
+       if (InBounds(location)) 
+       { 
+           int coord = MapCoord(location.x, location.y);
+           mapSeen.Add(coord);
+           mapVisible.Add(coord);
+       }
+   }

+   // Returns true if a given location has been seen at some point
+   public bool GetSeen(int coord)
+   {
+       return mapSeen.Contains(coord);
+   }

+   // Returns true if a given location is visible
+   public bool GetVisible(int coord)
+   {
+       return mapVisible.Contains(coord);
+   }
    
    ...

    // Render map as ascii characters
    public void Render() {
-   Console.WriteLine("GENERATED MAP " + width.ToString() + "x" + height.ToString());
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
+               int coord = MapCoord(x, y);
                char tileChar = '.';
+               Console.ForegroundColor = ConsoleColor.White;

+               // Render player
+               if (Game.player.x == x && Game.player.y == y){ tileChar = '@'; }

+               // Check if location has been seen
+               else if (GetSeen(coord))
+               {
                    if (map[x, y] == true)
                    {
                        tileChar = ' ';
                    }
                    else if (map[x, y] == false)
                    {
                        tileChar = '#';
                    }
                    
                    // Visualize light intensity
+                   if (GetVisible(coord))
+                   {
                        int lightIntensity = GetLightIntensity(x, y);
                        if (lightIntensity > 16) { Console.BackgroundColor = ConsoleColor.Yellow; }
                        else if (lightIntensity > 8) { Console.BackgroundColor = ConsoleColor.Gray; }
                        else if (lightIntensity > 0) { Console.BackgroundColor = ConsoleColor.DarkGray; }
                        else { Console.BackgroundColor = ConsoleColor.Black; }
+                   }
+               }

+               // Fade out non-visible locations
+               if (!GetVisible(coord)) { Console.ForegroundColor = ConsoleColor.DarkGray; }

                // Write char to console
                Console.Write(tileChar);
+               Console.ResetColor();
            }
            
            // Go to next line
            Console.Write(Environment.NewLine);
        }
    }

    ...
```

<div class="block-title">Player.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Player controlled character.
/// </summary>
public class Player
{
    public int x { get; private set; }
    public int y { get; private set; }
    private int visionRange = 16;

    public Player()
    {
        Spawn();
        Fov();
    }

    private void Spawn()
    {
        Room room = Game.map.tree.FindLeftLeaf(Game.map.tree.root).room;
        this.x = room.x + 1;
        this.y = room.y + 1;
    }

    private void Fov()
    {
        Game.map.ClearVisible();
        Shadowcast.Run(Game.map, new Vec2(x, y));
    }

    public bool MoveUp()
    {
        if (Game.map.pathGraph.HasLocation(Game.map.MapCoord(x, y-1))) { y--; Fov(); return true; }
        return false;
    }

    public bool MoveDown()
    {
        if (Game.map.pathGraph.HasLocation(Game.map.MapCoord(x, y+1))) { y++; Fov(); return true; }
        return false;
    }
    
    public bool MoveLeft()
    {
        if (Game.map.pathGraph.HasLocation(Game.map.MapCoord(x-1, y))) { x--; Fov(); return true; }
        return false;
    }
    
    public bool MoveRight()
    {
        if (Game.map.pathGraph.HasLocation(Game.map.MapCoord(x+1, y))) { x++; Fov(); return true; }
        return false;
    }
}

```

<div class="block-title">ShadowCast.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Shadowcasting algorithm used for field-of-view.
/// Implementation based on:
/// "Symmetric Shadowcasting" by Albert Ford
/// https://www.albertford.com/shadowcasting/
/// </summary>
public static class Shadowcast
{

    // Walk through every quadrant and set visible locations
    public static void Run(Map map, Vec2 origin, int range = 99)
    {
        // Set current position to visible
        map.SetVisible(origin);

        // Scan all four quadrants (north, south, east, west)
        for (int quadrant = 0; quadrant < 4; quadrant++)
        {
            Scan(map, origin, quadrant, 1, -1, 1, range);
        }
    }
    
    // Recursively scan through rows and columns in a given quadrant
    private static void Scan(Map map, Vec2 origin, int quadrant, int row, float startSlope, float endSlope, int range)
    {
        // Set start and end column numbers based on slope
        bool rowVisible = false;
        int minCol = (int)Math.Floor(((float)row * (float)startSlope) + (float)0.5);
        int maxCol = (int)Math.Ceiling(((float)row * (float)endSlope) - (float)0.5);
        for (int col = minCol; col <= maxCol; col++)
        {
            // Set current world position
            Vec2 pos = Location(origin, quadrant, row, col);

            // Check if current column is visible
            if ((map.GetVisionBlocking(pos) || Symmetric(row, col, startSlope, endSlope)) && (row + Math.Abs(col)) <= range)
            {
                map.SetVisible(pos);
                rowVisible = true;
            }

            // Check if not the first column
            if (col != minCol)
            {
                // Set world position for previous column
                Vec2 posPrev = Location(origin, quadrant, row, col -1);

                // Check if previous location was wall and current location is floor
                if (map.GetVisionBlocking(posPrev) && !map.GetVisionBlocking(pos))
                {
                    startSlope = Slope(row, col);
                }

                // Check if previous location was floor and current location is wall
                if (!map.GetVisionBlocking(posPrev) && map.GetVisionBlocking(pos) && row < range)
                {
                    Scan(map, origin, quadrant, row + 1, startSlope, Slope(row, col), range);
                }
            }

            // Check if last column is floor
            if (col == maxCol && !map.GetVisionBlocking(pos) && rowVisible && row < range)
            {
                Scan(map, origin, quadrant, row + 1, startSlope, endSlope, range);
            }
        }
    }

    // Calculate start slope or end slope
    private static float Slope(int row, int col)
    {
        return ((float)2.0 * (float)col - (float)1.0) / ((float)2.0 * (float)row);
    }

    // Checks if a given location can be seen symmetrically from origin location
    private static bool Symmetric(int row, int col, float startSlope, float endSlope)
    {
        return ((float)col >= (float)row * startSlope && (float)col <= (float)row * endSlope);
    }

    // Transform row/column in quadrant to location in world space
    private static Vec2 Location(Vec2 origin, int quadrant, int row, int col)
    {
        switch (quadrant)
        {
            // North
            case 0: return new Vec2(origin.x + col, origin.y - row);
            // South
            case 1: return new Vec2(origin.x + col, origin.y + row);
            // East
            case 2: return new Vec2(origin.x + row, origin.y + col);
            // West
            case 3: return new Vec2(origin.x - row, origin.y + col);
        }
        return null;
    }
}
```

### Extra
---

Here is an alternative shadowcasting algorithm based on [What the Hero Sees: Field-of-View for Roguelikes](https://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/) by [Bob Nystrom](https://x.com/munificentbob).

But this implementation isn't 100% complete and needs some more work (since so far I couldn't get corners of rooms to be set as visible properly).

<div class="block-title">Player.cs:</div>

```diff
    ...

    private void Fov()
    {
        Game.map.ClearVisible();
-       Shadowcast.Run(Game.map, new Vec2(x, y));
+       ShadowcastAlt.Run(Game.map, new Vec2(x, y));
    }

    ...
```

<div class="block-title">ShadowCastAlt.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Shadowcasting algorithm used for field-of-view.
/// Implementation based on:
/// "What the Hero Sees: Field-of-View for Roguelikes" by Bob Nystrom
/// https://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/
/// </summary>
public static class ShadowcastAlt
{
    // Go through every octant and set visible locations
    public static void Run(Map map, Vec2 origin)
    {
        map.SetVisible(origin);
        
        // Scan all eight octants
        for (int octant = 0; octant < 8; octant++)
        {
            Scan(map, origin, octant);
        }
    }
    
    private class Shadow
    {
        public float start { get; set; }
        public float end { get; set; }
        
        public Shadow(int row, int col)
        {
            this.start = (float)col / ((float)row + (float)2.0);
            this.end = ((float)col + (float)1.0) / ((float)row + (float)1.0);
        }
    }
    
    private class Shadowlist
    {
        private List<Shadow> shadows = new List<Shadow>();
        public bool fullShadow { get; private set; }
    
        // Check if current location is visible or covered in shadow
        public bool IsVisible(Shadow projection)
        {
            foreach (Shadow shadow in shadows)
            {
                if (shadow.start <= projection.start && shadow.end >= projection.end) { return false; }
            }
            return true;
        }
    
        // Add shadow to shadowlist
        public void Add(Shadow shadow)
        {
            // Find out where to put the new shadow in the list
            int index = 0;
            for (index = 0; index < shadows.Count; index++)
            {
                // Stop when hitting the insertion point
                if (shadows[index].start >= shadow.start) { break; }
            }
    
            // Check if the new shadow overlaps the previous shadow
            Shadow overlappingPrev = null;
            if (index > 0 && shadows[index - 1].end >= shadow.start)
            {
                overlappingPrev = shadows[index - 1];
            }
    
            // Check if the new shadow overlaps the next shadow
            Shadow overlappingNext = null;
            if (index < shadows.Count && shadows[index].start <= shadow.end)
            {
                overlappingNext = shadows[index];
            }
    
            // Overlaps with the next shadow
            if (overlappingNext != null)
            {
                // Overlaps with both shadows so unify one and delete the other
                if (overlappingPrev != null)
                {
                    overlappingPrev.end = overlappingNext.end;
                    shadows.RemoveAt(index);
                }
                // Overlaps with only the next one so unify with that
                else if (overlappingNext.start > shadow.start)
                {
                    overlappingNext.start = shadow.start;
                }
            }
            // Does not overlap with the next shadow
            else
            {
                // Overlaps with only the previous one so unify with that
                if (overlappingPrev != null)
                {
                    if (overlappingPrev.end < shadow.end)
                    {
                        overlappingPrev.end = shadow.end;
                    }
                }
                // Does not overlap with anything so insert to the list
                else
                {
                    shadows.Insert(index, shadow);
                }
            }
        
            // Set fullshadow to true if shadow goes from 0 to 1
            fullShadow = (shadows.Count == 1) && (shadows[0].start == (float)0) && (shadows[0].end == (float)1.0);
        }
    }

    // Transform row/column in octant to world location 
    private static Vec2 Location(Vec2 origin, int row, int col, int octant)
    {
        switch (octant)
        {
            case 0: return new Vec2(origin.x + col, origin.y + row);
            case 1: return new Vec2(origin.x + col, origin.y - row);
            case 2: return new Vec2(origin.x - col, origin.y + row);
            case 3: return new Vec2(origin.x - col, origin.y - row);
            case 4: return new Vec2(origin.x + row, origin.y + col);
            case 5: return new Vec2(origin.x + row, origin.y - col);
            case 6: return new Vec2(origin.x - row, origin.y + col);
            case 7: return new Vec2(origin.x - row, origin.y - col);
        }
        return null;
    }

    // Loop through every location in octant
    private static void Scan(Map map, Vec2 origin, int octant, int maxRows = 99)
    {
        // Create a new shadowlist
        Shadowlist shadowlist = new Shadowlist();

        // Loop through row by row until going out of bounds or reaching fullShadow
        bool endScan = false;
        for (int row = 1; row < maxRows; row++)
        {
            // Loop through columns in the current row
            bool rowVisible = false;
            for (int col = 0; col <= row; col++)
            {
                // Set the current world location
                Vec2 pos = Location(origin, row, col, octant);

                // Stop when going out of bounds or reaching fullShadow
                if (shadowlist.fullShadow || (!map.InBounds(pos) && col == 0)) { endScan = true; break; }
                else if (!map.InBounds(pos)) { break; }
                
                // Make shadow projection for current location
                Shadow projection = new Shadow(row, col);

                // Check if location is visible
                if (shadowlist.IsVisible(projection)) 
                { 
                    map.SetVisible(pos); 
                    rowVisible = true; 
                    
                    // Add shadow projection to shadowlist if location blocks view
                    if (map.GetVisionBlocking(pos)) { shadowlist.Add(projection); }
                }
            }

            // End the scan
            if (!rowVisible || endScan){ break; }
        }
    }
}
```

### Conclusion
---

A super basic game loop is in place with a player that can move around with the arrow keys in a very simple dungeon.

{% include bash_command.html bash_command="dotnet run" bash_dir="~/Roguelike" %}

[![screenshot](/img/screenshot_2024-06-08-172537.png)](/img/screenshot_2024-06-08-172537.png){:target="_blank"}

Download the source code: [roguelike-devlog6.zip](/files/roguelike-devlog6.zip){:target="_blank"}

Find the project on GitHub: [lzzrhx/roguelike](https://github.com/lzzrhx/roguelike){:target="_blank"}
