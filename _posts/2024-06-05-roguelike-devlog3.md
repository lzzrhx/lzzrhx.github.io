---
layout: post
title: "C# roguelike, devlog 3: Pathfinding algorithms (Breadth-first search and A*)"
image: devlog3
---

### Introduction
---

<!--summary-->

Pathfinding is a crucial component in almost any video game, and will be used in the next step of the dungeon generation to check if two given rooms are already connected when making corridors.

There are two types of pathfinding I will implement at this stage, the first one is *breadth-first search (BFS)*, and the second is *A\**.

<!--/summary-->

The video [A* Pathfinding (algorithm explanation)](https://youtu.be/-L-WgKMFuhE){:target="_blank"} by [Sebastian Lague](https://x.com/sebastianlague){:target="_blank"} gives a very good visual explaination of the A* pathfinding algorithm.

The following articles by [Amit Patel](https://x.com/redblobgames){:target="_blank"} thought me about pathfinding algorithms and how to implement them:
- [Introduction to the A* Algorithm](https://www.redblobgames.com/pathfinding/a-star/introduction.html){:target="_blank"}
- [Implementation of A*](https://www.redblobgames.com/pathfinding/a-star/implementation.html){:target="_blank"}
- [Breadth First Search: multiple start points](https://www.redblobgames.com/pathfinding/distance-to-any/){:target="_blank"}

### Implementation
---

I'll make a new class for pathfinding called *PathGraph* and add that to the *Map*.

With the goal of trying to keep the pathfinding datastructure as small and fast as possible I've chosed to represent each location in the world as a single number `((mapWidth * y) + x)` of the type *int*. *uint* would perhaps be more suitable here since the numbers never are negative, but I'll stick with *int* since working with *ints* is much easier than with *uints* in C# (most built-in functions use *int* so when using *uint* it requires constant casting to *int*) and since the max value for *int* is 2,147,483,647, which should be much more than enough for any use case.

To convert an x and y value to a single-number coordinate I'll add a `MapCoord()` method to the *Map* class.

But I'll also be working with X and Y coordinates so I'll set up a new datatype *Vec2* for that. It works just like a built-in *Vector2*, but uses *ints* instead of *floats* (for now the *Vec2* is very simple, but I can add more functionality as needed later).

In the *Map* class I'll also add a method `MapCoordReverse()` to convert a single-number map coordinate to a *Vec2*.

In *BspTree* I'll add some methods so that all the visitable locations are added to the *PathGraph* after the rooms have been created.

Next up is adding the *PathGraph* class.

It contains a reference to the `map` it belongs to and a dictionary of all the `locations` that are visitable, and for each location an array of neighbouring locations that are visitable.

It contains the following methods:
- `AstarCheck()` Uses the A* algorithm to check if a valid path exists between two given points on the map. Returns true if a valid path exists or false if not.
- `AstarPath()` Uses the A* algorithm to find a path between two given points on the map. It returns the path as a list of locations in order from start location to target location, or returns null if no valid path exists between the two given points.
- `BfsCheck()` Same as `AstarCheck()`, but uses the Breadth-first search algorithm instead.
- `BfsPath()` Same as `AstarPath()`, but uses the Breadth-first search algorithm instead.
- `BfsMap()` Uses the Breadth-first search algorithm to visit any valid location from a given location and returns a dictionary of visited locations. The dictionary key is the visited location and the dictionary value is the distance from the start location. The method also has an optional reverse parameter given as an *int*. If a reverse value is given the search starts at the given value and decrements as it gets further away from the start location until reaching zero.
- `Heuristic()` Gets the heuristic cost for a location. This is used in the A* algorithm to determine the cost for a given location.
- `GetCost()` Checks a given dictionary for a given location and returns the cost for that location. If the dictionary does not contain the location a default value is returned instead.
- `GetLocation()` Gets an array of all visitable neighbors of a given location from the `locations` dictionary.
- `SetLocation()` Adds a new or changes an existing location in the `locations` dictionary.
- `HasLocation()` Checks if the `locations` dictionary contains a given location.
- `TryAddNeighbor()` Add a new neighbor to a location in the `locations` dictionary. But only add the neighbor if a) the dictionary contains the location, and b) the location doesn't have the neighbor already.
- `AddRoom()` Add all visitable locations and from a given *Room* to the `locations` dictionary by using the `AddArea()` method.
- `AddArea()` Add all visitable locations from a given area to the `locations` dictionary. For each location it cecks for visitable neighbors. If the modifiyNeighbors parameter is set to *true* a check will also be made to see if the `locations` dictionary already contains the neighbor and modify it to add the current location as a neighbor. This is a more expensive operation, and isn't needed if adding isolated areas. But if adding an area that connects to an area that already exists in `locations` then modifyNeighbors should be set to *true*.

{% include folder_tree.html root="Roguelike" content="Roguelike.csproj,src|BspNode.cs|BspTree.cs|Game.cs|Map.cs|+PathGraph.cs|Rand.cs|Room.cs|+Vec2.cs" %}

<div class="block-title">Map.cs:</div>

```diff
    ...

    // Map size
    public readonly int width;
    public readonly int height;

    // Map data
    public BspTree tree { get; private set; }
    private bool?[,] map;
+   public readonly PathGraph pathGraph;

    // Constructor
    public Map(int width, int height)
    {
        this.width = width;
        this.height = height;
        this.map = new bool?[width, height];
+       this.pathGraph = new PathGraph(this);
        this.tree = new BspTree(this, width, height);
        BuildMap();
        Render();
    }

    ...

+   public int MapCoord(int x, int y)
+   {
+       return (width * y) + x;
+   }

+   // Converts mapcoord to Vec2
+   public Vec2 MapCoordReverse(int coord)
+   {
+       return new Vec2(coord % width, coord / width);
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

+       // Generate pathfinding graph for all the rooms
+       AddAllRoomsToPathGraph();
        
        // Print info for all nodes
        VisitAllNodes(NodeInfo);
    }

+   // Add all the rooms to the pathfinding graph
+   public void AddAllRoomsToPathGraph()
+   {
+       BspNode[] nodes = NodeArray();
+       foreach (BspNode node in nodes) { if (node.HasRoom()) { map.pathGraph.AddRoom(node.room); }}
+   }

    
+   // Return an array containing all nodes
+   public BspNode[] NodeArray()
+   {
+       BspNode[] nodeArray = new BspNode[BspNode.count];
+       NodeArrayAdd(root, ref nodeArray);
+       return nodeArray;
+   }
+   
+   // Traverse all child nodes and add to array
+   private void NodeArrayAdd(BspNode node, ref BspNode[] nodeArray)
+   {
+       nodeArray[node.id] = node;
+       if (node.children[0] != null) { NodeArrayAdd(node.children[0], ref nodeArray); }
+       if (node.children[1] != null) { NodeArrayAdd(node.children[1], ref nodeArray); }
+   }

    ...
```

<div class="block-title">Vec2.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Integer Vector 2.
/// </summary>
public class Vec2 
{
    public int x { get; set; }
    public int y { get; set; }

    public Vec2(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    public static Vec2 operator +(Vec2 a, Vec2 b)
    {
        return new Vec2(a.x + b.x, a.y + b.y);
    }
}
```

<div class="block-title">PathGraph.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// A data structure that contains visitable locations and its neighbors and algorithms for pathfinding.
/// </summary>
public class PathGraph
{
    // The map this pathgraph belongs to
    public readonly Map map;

    // Stores a location and its visitable neighbors
    private Dictionary<int, int[]> locations = new Dictionary<int, int[]>();
    
    // Constructor
    public PathGraph(Map map) 
    {
        this.map = map;
    }

    // A* search to check if a valid path exists between start and end locations
    public bool AstarCheck(int start, int target, Dictionary<int, int> costs = null)
    {
        // Check if start/end locations are visitable
        if (!HasLocation(start) || !HasLocation(target)) { return false; }

        // Locations to visit
        PriorityQueue<int, int> toVisit = new PriorityQueue<int, int>();
        toVisit.Enqueue(start, 0);

        // Dictionary of all reached locations and cost to get there
        Dictionary<int, int> costSoFar = new Dictionary<int, int>();
        costSoFar.Add(start, 0);

        // Start search
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();
            
            // Target found
            if (current == target) { return true; }

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
                int nextCost = (costs != null ? GetCost(costs, next, 1) : 1);
                int newCost = costSoFar[current] + nextCost;
                if (!costSoFar.ContainsKey(next) || newCost < costSoFar[next])
                {
                    toVisit.Enqueue(next, newCost + Heuristic(next, target));
                    costSoFar[next] = newCost;
                }
            }
        }

        // Target not found
        return false;
    }
    
    // A* search to find the shortest path between two locations
    public List<int> AstarPath(int start, int target, Dictionary<int, int> costs = null)
    {
        // Check if start/end locations are visitable
        if (!HasLocation(start) || !HasLocation(target) || start == target) { return null; }

        // Locations to visit
        PriorityQueue<int, int> toVisit = new PriorityQueue<int, int>();
        toVisit.Enqueue(start, 0);

        // Dictionary of all reached locations and the previously visited location
        Dictionary<int, int> cameFrom = new Dictionary<int, int>();
        cameFrom.Add(start, start);

        // Dictionary of all reached locations and cost to get there
        Dictionary<int, int> costSoFar = new Dictionary<int, int>();
        costSoFar.Add(start, 0);

        // Start search
        bool found = false;
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();
            
            // Target found
            if (current == target) { found = true; break; }

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
                int nextCost = (costs != null ? GetCost(costs, next, 1) : 1);
                int newCost = costSoFar[current] + nextCost;
                if (!costSoFar.ContainsKey(next) || newCost < costSoFar[next]) {
                    toVisit.Enqueue(next, newCost + Heuristic(next, target));
                    cameFrom[next] = current;
                    costSoFar[next] = newCost;
                }
            }
        }

        // Retrace path from target to start
        if (found)
        {
            List<int> path = new List<int>();
            int current = target;
            while (cameFrom[current] != current)
            {
                path.Add(current);
                current = cameFrom[current];
            }
            path.Reverse();

            // Return path from start location to target location
            return path;
        }

        // Target location not found
        return null;
    }

    // Breadth-first search (BFS) to check if a valid path exists between start and end locations
    public bool BfsCheck(int start, int target)
    {
        // Check if start/end locations are visitable
        if (!HasLocation(start) || !HasLocation(target)) { return false; }

        // Locations to visit
        Queue<int> toVisit = new Queue<int>();
        toVisit.Enqueue(start);

        // Dictionary of all reached locations and the previously visited location
        Dictionary<int, int> cameFrom = new Dictionary<int, int>();
        cameFrom.Add(start, start);

        // Start search
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();
            
            // Target found
            if (current == target) { return true; }

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
                if (!cameFrom.ContainsKey(next)) {
                    toVisit.Enqueue(next);
                    cameFrom.Add(next, current);
                }
            }
        }

        // Target not found
        return false;
    }
    
    // Breadth-first search (BFS) to find the shortest path between two locations
    public List<int> BfsPath(int start, int target)
    {
        // Check if start/end locations are visitable
        if (!HasLocation(start) || !HasLocation(target) || start == target) { return null; }

        // Locations to visit
        Queue<int> toVisit = new Queue<int>();
        toVisit.Enqueue(start);

        // Dictionary of all reached locations and the previously visited location
        Dictionary<int, int> cameFrom = new Dictionary<int, int>();
        cameFrom.Add(start, start);

        // Start search
        bool found = false;
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();
            
            // Target found
            if (current == target) { found = true; break; }

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
                if (!cameFrom.ContainsKey(next)) {
                    toVisit.Enqueue(next);
                    cameFrom.Add(next, current);
                }
            }
        }

        // Retrace path from target to start
        if (found)
        {
            List<int> path = new List<int>();
            int current = target;
            while (cameFrom[current] != current)
            {
                path.Add(current);
                current = cameFrom[current];
            }
            path.Reverse();

            // Return path from start location to target location
            return path;
        }

        // Target location not found
        return null;
    }
    
    // Breadth-first search (BFS) to generate a map of values to/from (depends if reverse is null or not) a list of start locations
    public Dictionary<int, int> BfsMap(List<int> start, int? reverse = null)
    {
        // Locations to visit
        Queue<int> toVisit = new Queue<int>();

        // Dictionary of all reached locations and the previously visited location
        Dictionary<int, int> cameFrom = new Dictionary<int, int>();
        
        // Dictionary of all reached location and distance to start
        Dictionary<int, int> distanceTo = new Dictionary<int, int>();

        // Add start locations
        foreach (int location in start) 
        { 
            if (!HasLocation(location)) { return null; }
            toVisit.Enqueue(location); 
            cameFrom.Add(location, location);
            distanceTo.Add(location, (reverse != null ? (int)(reverse) : 0)); 
        }

        // Start search
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
            if (!cameFrom.ContainsKey(next)) {
                if (reverse == null || distanceTo[current] - 1 > 0)
                    {
                        toVisit.Enqueue(next);
                        cameFrom.Add(next, current);
                        distanceTo.Add(next, (reverse != null ? distanceTo[current] - 1 : distanceTo[current] + 1));
                    }
                }
            }
        }

        // Return the map
        return distanceTo;
    }

    // Return heuristic cost for a location
    private int Heuristic(int aCoord, int bCoord)
    {
        Vec2 a = map.MapCoordReverse(aCoord);
        Vec2 b = map.MapCoordReverse(bCoord);
        return Math.Abs(a.x - b.x) + Math.Abs(a.y - b.y);
    }
    
    // Return cost for a location
    public int GetCost(Dictionary<int, int> costs, int location, int defaultCost = 1) 
    { 
        int cost = 0;
        if (costs.TryGetValue(location, out cost))
        { return cost; }
        else { return defaultCost; }
    }

    // Return visitable neighbors for a given location
    public int[] GetLocation(int location) 
    { 
        return locations[location]; 
    }

    // Set visitable neighbors for a given location
    public void SetLocation(int location, int[] neighbors)
    { 
        locations[location] = neighbors;
    }

    // Check if location exists in the graph
    public bool HasLocation(int location)
    {
        return locations.ContainsKey(location);
    }

    // Try to add a new neighbor to a location, only add if location exists and doesn't have the neighbor already
    public void TryAddNeighbor(int location, int neighbor)
    {
        if (HasLocation(location))
        {
            if (!GetLocation(location).Contains(neighbor))
            {
                List<int> neighbors = GetLocation(location).ToList();
                neighbors.Add(neighbor);
                SetLocation(location, neighbors.ToArray());
            }
        }
    }
    
    // Add all visitable locations from a room
    public void AddRoom(Room room, bool modifyNeighbors = false)
    {
        AddArea(room.x, room.y, room.width, room.height, room.area, modifyNeighbors);
    }
    
    // Add all visitable locations from an area
    public void AddArea(int worldX, int worldY, int width, int height, bool?[,] area, bool modifyNeighbors = false)
    {
        // Create a temporary dictionary for new nodes to be added to the nodes dictionary
        Dictionary<int, int[]> newLocations = new Dictionary<int, int[]>();

        // Loop through the area and check locations
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                if (area[x, y] == true)
                {
                    // Get the current position
                    int thisPosition = map.MapCoord(worldX + x, worldY + y);

                    // Make list to populate with visitable neighbors
                    List<int> neighbors = new List<int>();
                    
                    // Check if neighbor above the current location is a visitable location
                    bool upInBounds = worldY + y > 0;
                    if (upInBounds)
                    {
                        int upPosition = map.MapCoord(worldX + x, worldY + y - 1);
                        bool upPossible = HasLocation(upPosition) ? true : (y > 0 ? area[x, y-1] == true : false);
                        if (upPossible)
                        {
                            neighbors.Add(upPosition);
                            if (modifyNeighbors){ TryAddNeighbor(upPosition, thisPosition); }
                        }
                    }
                    
                    // Check if right-side neighbor is a visitable location
                    bool rightInBounds = worldX + x + 1 < map.width;
                    if (rightInBounds)
                    {
                        int rightPosition = map.MapCoord(worldX + x + 1, worldY + y);
                        bool rightPossible = HasLocation(rightPosition) ? true : (x + 1 < width ? area[x+1, y] == true : false);
                        if (rightPossible)
                        {
                            neighbors.Add(rightPosition);
                            if (modifyNeighbors){ TryAddNeighbor(rightPosition, thisPosition); }
                        }
                    }
                    
                    // Check if neighbor under the under current location is a visitable location
                    bool downInBounds = worldY + y + 1 < map.height;
                    if (downInBounds) {
                        int downPosition = map.MapCoord(worldX + x, worldY + y + 1);
                        bool downPossible = HasLocation(downPosition) ? true : (y + 1 < height ? area[x, y+1] == true : false);
                        if (downPossible)
                        {
                            neighbors.Add(downPosition);
                            if (modifyNeighbors){ TryAddNeighbor(downPosition, thisPosition); }
                        }
                    }
                    
                    // Check if left-side neighbor is a visitable location
                    bool leftInBounds = worldX + x > 0;
                    if (leftInBounds)
                    {
                        int leftPosition = map.MapCoord(worldX + x - 1, worldY + y);
                        bool leftPossible = HasLocation(leftPosition) ? true : (x > 0 ? area[x-1, y] == true : false);
                        if (leftPossible)
                        {
                            neighbors.Add(leftPosition);
                            if (modifyNeighbors){ TryAddNeighbor(leftPosition, thisPosition); }
                        }
                    }
                    
                    // Add the current location with its neighbors to the location dictionary
                    newLocations.Add(thisPosition, neighbors.ToArray());
                }
            }
        }
        
        // Add the found nodes to the main nodes dictionary
        foreach (KeyValuePair<int, int[]> location in newLocations) 
        {
            if (!HasLocation(location.Key)) { SetLocation(location.Key, location.Value); }
        }
    }
};
```

### Conclusion
---

I'll temporarily modify *Map.cs* and *PathGraph.cs* a bit to test the pathfinding algorithms:

<div class="block-title">Map.cs:</div>

```diff
    ...

    // Map size
    public readonly int width;
    public readonly int height;

    // Map data
    public BspTree tree { get; private set; }
-   private bool?[,] map;
+   public bool?[,] map;
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
+       // Pathfinding test
+       // (96 * y) + x position of start and target position in pathfinding test
+       if (pathGraph.BfsCheck((96*5) + 10, (96*10) + 20)) { Console.WriteLine("PATH FOUND!"); } else { Console.WriteLine("PATH NOT FOUND!"); }
        Render();
    }

    ...
```

<div class="block-title">PathGraph.cs:</div>

```diff
    ...

    // Breadth-first search (BFS) to check if a valid path exists between start and end locations
    public bool BfsCheck(int start, int target)
    {
        // Check if start/end locations are visitable
        if (!HasLocation(start) || !HasLocation(target)) { return false; }

        // Locations to visit
        Queue<int> toVisit = new Queue<int>();
        toVisit.Enqueue(start);

        // Dictionary of all reached locations and the previously visited location
        Dictionary<int, int> cameFrom = new Dictionary<int, int>();
        cameFrom.Add(start, start);

        // Start search
        while (toVisit.Count > 0)
        {
            int current = toVisit.Dequeue();

+           // Render searched locations as wall (for testing)
+           Vec2 pos = map.MapCoordReverse(current);
+           map.map[pos.x, pos.y] = false;
            
            // Target found
            if (current == target) { return true; }

            // Search neighbors
            foreach (int next in GetLocation(current))
            {
                if (!cameFrom.ContainsKey(next)) {
                    toVisit.Enqueue(next);
                    cameFrom.Add(next, current);
                }
            }
        }

    ...
```
{% include bash_command.html bash_command="dotnet run" bash_dir="~/Roguelike" %}

[![screenshot](/img/screenshot_2024-06-08-024146.png)](/img/screenshot_2024-06-08-024146.png){:target="_blank"}

Download the source code: [roguelike-devlog3.zip](/files/roguelike-devlog3.zip){:target="_blank"}

Find the project on GitHub: [lzzrhx/roguelike](https://github.com/lzzrhx/roguelike){:target="_blank"}
