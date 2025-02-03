---
layout: post
title: "C# roguelike, devlog 4: Corridors"
image: devlog4
---

### Introduction
---

<!--summary-->

Now that some pathfinding algorithms are in place it's time to move on to the next step, making corridors between the rooms.

<!--/summary-->

### Implementation
---

Upon creation a corridor should take two points on the *Map* as arguments and then walk step by step from the start location to the end location and generate walkable space along the way. Placing a door when exiting or entering a room. Additionally to avoid duplicate paths a corridor should only be made between two rooms if no path between the rooms already exits.

I'll add a new *Corridor* class with `x` & `y` coordinates, `width` & `height` dimensions and a reference to the parent `node`. The *Corridor* data will be stored in a 2D `area` array similar to how areas are stored in in *Room* and *Map*, and additionally the corridor will have a list of `doors` with each door stored as a single-number coordinate *int*.

In the constructor the two points given as arguments are evaluted. If the first point is to the right of the second point they get switched so that point 0 (`x0` & `y0`) is always to the left of point 1 (`x1` & `y1`). Then a check is made to see if point 0 is above or below point 1. Let's imagine a box drawn between the two points. The `x` and `y` values of the *Corridor* are set to the upper-left corner of the box, the `width` & `height` are set to the width & height of the imagined box, and the `area` is set to a new 2D array with the same dimensions. Then the `Generate()` method gets called with a startPointBelow bool as an argument, indicating if point 0 is below point 1.

- The `Generate()` method sets a start point and a goal point, it then proceeds to walk the entire distance by calling `WalkUp()`, `WalkRight()` and `WalkDown()` in a loop until the goal point is reached. There is a random chance that a walk is interrupted from time to time, resulting in corridors that are not always straight, but sometimes cornered. The corridor generation is done in chunks, collision checks are performed on every step of the walk to check if the current location or its immediate neighbors are already defined as walkable space in a previously made room or corridor. If a location of previously made walkable space is reached the current chunk is ended and evaluated. The evaluation checks if a valid path already exists between the start point of the chunk and the end point. If a valid path already exits the chunk is discarded, but if a valid path does not already exist then the chunk is added to the `area` and becomes part of the final *Corridor*. The process is repeated chunk by chunk until the final goal point is reached. 
- `WalkUp()`, `WalkRight()` and `WalkDown()` walks location by location from a given point towards a given point. On each step there is a small chance that the walk is interrupted. And each location on each step of the way is processed by calling `HandleLocation()`.
- `HandleLocation()` checks if the current location and its neighbors are already walkable space in a previously made room or corridor. It tracks the exiting and entering of rooms along the walk and places doors when exiting or entering. It also tells `Generate()` to end the current chunk when reaching, on the current location or on its neighboring locations, already walkable space.

In the *PathGraph* class I'll add a method for adding corridors to the graph.

I'll modify the *BspNode* class and add a `corridor` class to it, plus adding a method `HasCorridor()` that checks if there is a corridor for the current node.

In the *BspTree* class I'll add a `GenerateCorridor()` method that get's called for all nodes after the rooms have been added to the *PathGraph*, and some methods for collision checking, to see if a given point in the tree is part of a room or a corridor and if it is walkable space.

- `GenerateCorridor()` This method only runs on nodes that have children. It finds the room in the rightmost leaf of the left side child and room in the leftmost leaf of the right child of a given node. It then picks a random point in each of the two rooms, checks if a valid path exists between them, and if no path already exists then a new corridor is created between the rooms.
- `CheckCollision()` Checks if a given point is within a room or a corridor and returns the nullable bool from the selected point, where *null* is, as before, void space, but *true* and *false* is flipped, so *true* means wall collision found and a *false* value means open space. The method can check for rooms and corridors at the same time, or check only rooms or only corridors depending on the given arguments. The check is performed on a given node and recursively checks all child nodes.
- `CheckCollisionAll()` Performs collision check for all nodes in the entire tree by calling `CheckCollision()` on the root node.

Finally in the *Map* class I'll add some new methods for adding the corridors of the tree to the map.

{% include folder_tree.html root="Roguelike" content="Roguelike.csproj,src|BspNode.cs|BspTree.cs|+Corridor.cs|Game.cs|Map.cs|PathGraph.cs|Rand.cs|Room.cs|Vec2.cs" %}

<div class="block-title">Map.cs:</div>

```diff
    ...
    
    // Build the map
    private void BuildMap() {

        // Build all rooms
        tree.VisitAllNodes(BuildRoom);

+       // Build all corridors
+       tree.VisitAllNodes(BuildCorridor);
    }

+   // Add a door to the map
+   public void AddDoor(int x, int y)
+   {
+       int coord = MapCoord(x, y);
+       if (map[x, y] == true)
+       { 
+           // Add door here
+       }
+   }

    // Build room from a node
    private void BuildRoom(BspNode node)
    {
        if (node.HasRoom())
        {
            Room room = node.room;
            BuildSpace(room.x, room.y, room.width, room.height, room.area);
        }
    }

+   // Build corridor from a node
+   private void BuildCorridor(BspNode node)
+   {
+       // Build corridor
+       if (node.HasCorridor())
+       {
+           Corridor corridor = node.corridor;
+           BuildSpace(corridor.x, corridor.y, corridor.width, corridor.height, corridor.area);
+           
+           // Add doors
+           foreach (Vec2 door in corridor.doors)
+           {
+               AddDoor(corridor.x + door.x, corridor.y + door.y);
+           }
+       }
+   }
    
    ...
```

<div class="block-title">BspTree.cs:</div>

```diff
    ...

    // Constructor
    public BspTree(Map map, int width, int height, int x = 0, int y = 0)
    {
        this.id = count;
        count++;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.map = map;
        
        // Generate all nodes and rooms
        this.root = new BspNode(this, width, height);

        // Generate pathfinding graph for all the rooms
        AddAllRoomsToPathGraph();

+       // Generate corridors
+       VisitAllNodes(GenerateCorridor);

        // Print info for all nodes
        VisitAllNodes(NodeInfo);
    }

+   // Generate a corridor for the current node, between the rightmost leaf of the left child, and the leftmost leaf of the right child
+   private void GenerateCorridor(BspNode node)
+   {
+       if (node.children[0] != null && node.children[1] != null)
+       {
+           // Set start and endpoints for the corridor
+           Room roomFirst = FindRightLeaf(node.children[0]).room;
+           Room roomSecond = FindLeftLeaf(node.children[1]).room;
+           int x0 = roomFirst.x + Math.Min(roomFirst.width - 1, Rand.random.Next(2, roomFirst.width - 3));
+           int y0 = roomFirst.y + Math.Min(roomFirst.height - 1, Rand.random.Next(2, roomFirst.height - 3));
+           int x1 = roomSecond.x + Math.Min(roomSecond.width - 1, Rand.random.Next(2, roomSecond.width - 3));
+           int y1 = roomSecond.y + Math.Min(roomSecond.height - 1, Rand.random.Next(2, roomSecond.height - 3));
+            
+           // Check if path already exists between startpoint and endpoint, if path doesn't exist make new corridor
+           if (!map.pathGraph.BfsCheck(map.MapCoord(x0, y0), map.MapCoord(x1, y1)))
+           {
+               node.corridor = new Corridor(node, x0, y0, x1, y1 );
+               map.pathGraph.AddCorridor(node.corridor, modifyNeighbors: true);
+           }
+       }
+   }
+   
+   // Check all nodes if a given point is inside a room
+   public bool? CheckCollisionAll(int x, int y, bool room = true, bool corridor = true)
+   {
+       // Check if within map bounds
+       if ((room || corridor) && (x > 0 || x < map.width || y > 0 || y < map.height))
+       {
+           // Perform collision check
+           return CheckCollision(root, x, y, room, corridor);
+       }
+       
+       // Return null if out of bounds
+       return null;
+   }
+   
+   // Check if given point is inside a room in a given node, if no collision found recursivly check all child nodes
+   public bool? CheckCollision(BspNode node, int x, int y, bool room = true, bool corridor = true)
+   {
+       bool? collisionFound = null;
+        
+       // Check for collision in room
+       if (collisionFound == null && node.room != null && room == true)
+       {
+           Room r = node.room;
+           if ((x >= r.x) && (x < r.x + r.width) && (y >= r.y) && (y < r.y + r.height)) 
+           {
+               collisionFound = r.area[x-r.x, y-r.y];
+               if (collisionFound == true) { collisionFound = false; }
+               else if (collisionFound == false) { collisionFound = true; }
+           }
+       }
+       
+       // Check for collision in corridor
+       if (collisionFound == null && node.corridor != null && corridor == true)
+       {
+           Corridor c = node.corridor;
+           if ((x >= c.x) && (x < c.x + c.width) && (y >= c.y) && (y < c.y + c.height)) 
+           {
+               collisionFound = c.area[x-c.x, y-c.y];
+               if (collisionFound == true) { collisionFound = false; }
+               else if (collisionFound == false) { collisionFound = true; }
+           }
+       }
+       
+       // Check for collision in children nodes recursively
+       if (collisionFound == null && node.children[0] != null) { collisionFound = CheckCollision(node.children[0], x, y, room, corridor); }
+       if (collisionFound == null && node.children[1] != null) { collisionFound = CheckCollision(node.children[1], x, y, room, corridor); }
+       
+       // Return collision
+       return collisionFound;
+   }

    ...
```

<div class="block-title">BspNode.cs:</div>

```diff
    ...
    
    // Node data
    public Room room { get; private set; } = null;
+   public Corridor corridor { get; set; } = null;

    ...
    
    // Return true if this node has a room
    public bool HasRoom()
    {
        if (room != null) { return true; }
        return false;
    }

+   // Return true if this node has a corridor
+   public bool HasCorridor()
+   {
+       if (corridor != null) { return true; }
+       return false;
+   }
    
    ...
```

<div class="block-title">PathGraph.cs:</div>

```diff
    ...

    // Add all visitable locations from a room
    public void AddRoom(Room room, bool modifyNeighbors = false)
    {
        AddArea(room.x, room.y, room.width, room.height, room.area, modifyNeighbors);
    }

+   // Add all visitable locations from a corridor
+   public void AddCorridor(Corridor corridor, bool modifyNeighbors = false)
+   {
+       AddArea(corridor.x, corridor.y, corridor.width, corridor.height, corridor.area, modifyNeighbors);
+   }
    
    ...
```

<div class="block-title">Corridor.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// A corridor between two spaces.
/// </summary>
public class Corridor 
{
    public readonly int x;
    public readonly int y;
    public readonly int width;
    public readonly int height;
    
    // Parent node
    public readonly BspNode node;

    // Corridor data
    public bool?[,] area { get; private set; }
    public List<Vec2> doors { get; private set; } = new List<Vec2>();

    // Constructor
    public Corridor(BspNode node, int x0, int y0, int x1, int y1)
    {
        // Make sure startpoint is to the left of endpoint
        if (x0 > x1)
        {
            int xTemp = x0;
            int yTemp = y0;
            x0 = x1;
            y0 = y1;
            x1 = xTemp;
            y1 = yTemp;
        }
        
        int x = x0;
        int y = y0;
        
        // Check if startpoint is below endpoint
        bool startPointBelow = false;
        if (y0 > y1)
        { 
            startPointBelow = true;
            y = y1; 
        }

        int width = Math.Abs(x0 - x1) + 1;
        int height = Math.Abs(y0 - y1) + 1;
        this.x = x;
        this.y = y;
        this.node = node;
        this.width = width;
        this.height = height;
        this.area = new bool?[width, height];

        // Generate corridor
        Generate(startPointBelow);
    }
   
    // Check for collision and try to place tile at current position
    private bool HandleLocation(int x, int y, int xPrev, int yPrev, ref bool? collisionRoomPrev, bool?[,] chunkArea, List<Vec2> chunkDoors, ref bool tryFinishChunk)
    {
        // Check collision
        bool? collisionRoom = node.tree.CheckCollisionAll(this.x + x, this.y + y, room: true, corridor: false);
        bool? collisionCorridor = node.tree.CheckCollisionAll(this.x + x, this.y + y, room: false, corridor: true);
        
        // Check if entered or exited room and corridor
        bool enteredRoom = false;
        bool exitedRoom = false;
        if (collisionRoom != null && collisionRoomPrev == null) { enteredRoom = true; }
        if (collisionRoom == null && collisionRoomPrev != null) { exitedRoom = true; }
        
        // Check for collision in neighbors
        bool? collisionUp = node.tree.CheckCollisionAll(this.x + x, this.y + y - 1);;
        bool? collisionDown = node.tree.CheckCollisionAll(this.x + x, this.y + y + 1);;
        bool? collisionLeft = node.tree.CheckCollisionAll(this.x + x - 1, this.y + y);;
        bool? collisionRight = node.tree.CheckCollisionAll(this.x + x + 1, this.y + y);;

        // Group collisions
        bool collisionAllAny = (collisionCorridor != null || collisionRoom != null || collisionUp != null || collisionDown != null || collisionLeft != null || collisionRight != null);
        bool collisionAllVisitable = (collisionCorridor == false || collisionRoom == false || collisionUp == false || collisionDown == false || collisionLeft == false || collisionRight == false);
            
        // Set current location to open space
        chunkArea[x, y] = true;
        
        // Add door when exiting room
        if (exitedRoom) { chunkDoors.Add(new Vec2(xPrev, yPrev)); }

        // Add door when entering room
        if (enteredRoom) { chunkDoors.Add(new Vec2(x, y)); }
       
        // Set the prev collisions
        collisionRoomPrev = collisionRoom;

        // Finish the chunk when reaching a visitable space
        if (collisionAllVisitable && tryFinishChunk) { return true;  }

        // Try to end the chunk after entering a room or a corridor
        if (collisionRoom != false && collisionCorridor != false) { tryFinishChunk = true; }

        return false;
    }

    // Make corridor from bottom to top
    private bool WalkUp(ref int x, ref int y, ref int xPrev, ref int yPrev, int xGoal, int yGoal, ref bool? collisionRoomPrev, bool?[,] chunkArea, List<Vec2> chunkDoors, ref bool tryFinishChunk)
    {
        while (y > yGoal)
        {

            if (Rand.Percent(10)) { return false; }
            if (HandleLocation(x, y, xPrev, yPrev, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk)) { return true; }
            xPrev = x;
            yPrev = y;
            y--;
        }
        return false;
    }
    
    // Make corridor from top to bottom
    private bool WalkDown(ref int x, ref int y, ref int xPrev, ref int yPrev, int xGoal, int yGoal, ref bool? collisionRoomPrev, bool?[,] chunkArea, List<Vec2> chunkDoors, ref bool tryFinishChunk)
    {
        while (y < yGoal)
        {
            if (Rand.Percent(10)) { return false; }
            if (HandleLocation(x, y, xPrev, yPrev, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk)) { return true; }
            xPrev = x;
            yPrev = y;
            y++;
        }
        return false;
    }
    
    // Make corridor from left to right
    private bool WalkRight(ref int x, ref int y, ref int xPrev, ref int yPrev, int xGoal, int yGoal, ref bool? collisionRoomPrev, bool?[,] chunkArea, List<Vec2> chunkDoors, ref bool tryFinishChunk)
    {
        while (x < xGoal)
        {
            if (Rand.Percent(10)) { return false; }
            if (HandleLocation(x, y, xPrev, yPrev, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk)) { return true; }
            xPrev = x;
            yPrev = y;
            x++;
        }
        return false;
    }
    
    // Generate corridor
    private void Generate(bool startPointBelow)
    {
        // Set initial values
        int x = 0;
        int xGoal = width - 1;

        // The default is to draw corridor from top-left to bottom-right
        int y = 0;
        int yGoal = height - 1;

        // But if the startpoint is below the endpoint the corridor is drawn from bottom-left to top-right
        if (startPointBelow)
        {
            y = yGoal;
            yGoal = 0;
        }
        
        // Draw the corridor chunk by chunk
        int xPrev = x;
        int yPrev = y;
        bool? collisionRoomPrev = node.tree.CheckCollisionAll(this.x + x, this.y + y, room: true, corridor: false);
        while (x != xGoal || y != yGoal)
        {

            // Start new chunk, end chunk when reaching a new room
            bool validChunk = false;
            bool?[,] chunkArea = new bool?[width, height];
            List<Vec2> chunkDoors = new List<Vec2>();
            int xChunk = x;
            int yChunk = y;
            bool chunkDone = false;
            bool tryFinishChunk = false;
            while (!chunkDone && (x != xGoal || y != yGoal))
            {
                if (!chunkDone && yGoal < y) { chunkDone = WalkUp(ref x, ref y, ref xPrev, ref yPrev, xGoal, yGoal, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk); }
                if (!chunkDone && xGoal > x) { chunkDone = WalkRight(ref x, ref y, ref xPrev, ref yPrev, xGoal, yGoal, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk); }
                if (!chunkDone && yGoal > y) { chunkDone = WalkDown(ref x, ref y, ref xPrev, ref yPrev, xGoal, yGoal, ref collisionRoomPrev, chunkArea, chunkDoors, ref tryFinishChunk); }
            }
            
            // Check if start location is valid, if not valid then check neighbors
            int xStart = this.x + xChunk;
            int yStart = this.y + yChunk;
            bool validStartPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xStart, yStart));
            
            // Check position above
            if (!validStartPos && (yStart > 0)) 
            {
                if (validStartPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xStart, yStart - 1)))
                {
                    yStart = yStart - 1;
                }
            }

            // Check position below
            if (!validStartPos && (yStart + 1 < node.tree.map.height)) 
            {
                if (validStartPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xStart, yStart + 1)))
                {
                    yStart = yStart + 1;
                }
            }
            
            // Check position left
            if (!validStartPos && (xStart > 0)) 
            {
                if (validStartPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xStart - 1, yStart)))
                {
                    xStart = xStart - 1;
                }
            }
            
            // Check position right
            if (!validStartPos && (xStart + 1 < node.tree.map.width)) 
            {
                if (validStartPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xStart + 1, yStart)))
                {
                    xStart = xStart + 1;
                }
            }
            
            // Check if end location is valid, if not check neighbors
            int xEnd = this.x + x;
            int yEnd = this.y + y;
            bool validEndPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xEnd, yEnd));
            
            // Check position above
            if (validStartPos && !validEndPos && (yEnd > 0)) 
            {
                if (validEndPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xEnd, yEnd - 1)))
                {
                    yEnd = yEnd - 1;
                }
            }

            // Check position below
            if (validStartPos && !validEndPos && (yEnd + 1 < node.tree.map.height)) 
            {
                if (validEndPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xEnd, yEnd + 1)))
                {
                    yEnd = yEnd + 1;
                }
            }
            
            // Check position left
            if (validStartPos && !validEndPos && (xEnd > 0)) 
            {
                if (validEndPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xEnd - 1, yEnd)))
                {
                    xEnd = xEnd - 1;
                }
            }
            
            // Check position right
            if (validStartPos && !validEndPos && (xEnd + 1 < node.tree.map.width)) 
            {
                if (validEndPos = node.tree.map.pathGraph.HasLocation(node.tree.map.MapCoord(xEnd + 1, yEnd)))
                {
                    xEnd = xEnd + 1;
                }
            }

            // If both the start and end positions of the chunk is valid check if a path exists between the points
            if (validEndPos && validStartPos) { validChunk = !node.tree.map.pathGraph.BfsCheck(node.tree.map.MapCoord(xStart, yStart), node.tree.map.MapCoord(xEnd, yEnd)); }
            else { validChunk = false; }
            
            // Add chunk to the main area if path to chunk doesn't exist
            if (validChunk)
            {
                // Add doors
                doors.AddRange(chunkDoors);

                // Add chunk area
                for (int yC = 0; yC < height; yC++)
                {
                    for (int xC = 0; xC < width; xC++)
                    {
                        if (chunkArea[xC, yC] != null)
                        {
                            area[xC, yC] = chunkArea[xC, yC];
                        }
                    }
                }
            }
        }
    }
}
```

### Conclusion
---

And that's it, corridors are now made between all the rooms connecting them together. It might not be a super fast and efficient implementation and it might not result in ideal gameplay (backtracking), but it'll do for now.

{% include bash_command.html bash_command="dotnet run" bash_dir="~/Roguelike" %}

[![screenshot](/img/screenshot_2024-06-08-034604.png)](/img/screenshot_2024-06-08-034604.png){:target="_blank"}

Download the source code: [roguelike-devlog4.zip](/files/roguelike-devlog4.zip){:target="_blank"}

Find the project on GitHub: [lzzrhx/roguelike](https://github.com/lzzrhx/roguelike){:target="_blank"}
