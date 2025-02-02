---
layout: post
title: "C# roguelike, devlog 2: Binary space partitioning trees"
image: devlog2.png
---

### Introduction
---

<!--summary-->

I thought I'd start the project with creating a simple fixed size map and rendering it in the console.

The map generation technique I thought I'd try implementing involves using binary space partitioning to place rooms in a given space.

The technique is explained in the video presentation [Procedural Map Generation Techniques](https://youtu.be/TlLIOgWYVpI?t=298){:target="_blank"} by [Herbert Wolverson](https://x.com/herberticus){:target="_blank"}. And in the roguebasin article [Basic BSP Dungeon generation](https://roguebasin.com/index.php/Basic_BSP_Dungeon_generation){:target="_blank"}.

How a binary tree should function is quite well explained by Richard Fleming Jr in the videos [Binary Trees](https://youtu.be/S5y3ES4Rvkk){:target="_blank"} and [Tree Logic](https://youtu.be/Tb01dxMrIdc){:target="_blank"}.

<!--/summary-->

### Implementation
---

I'll setup a most basic *Map* class that contains a grid of nullable bools in a 2D array called `map`.

Bools with a *null* value are void spaces, *false* values are walls and bools that are set to *true*  are open spaces.

The `Map.Render()` method simply iterates through the array and prints a character on the screen according to the bool value.

The *Map* class contains a binary space partitioning tree that is used to build the map and set the values in the `map` array.

I'll make a new class for binary space partitioning trees and call it *BspTree*.

The *BspTree* has an `id` that auto increments upon the creation of new trees, a world position stored as `x` & `y` and dimensions stored as `width` & `height`. It also contains a `map` reference to the *Map* object that created it and a reference to the `root` node in the tree. Upon creation of the tree a new node is created and set as the `root`.

The tree class contains methods for traversing and listing the nodes in the tree:
- `NodeInfo()` Shows info about a given node.
- `VisitNodes()` Traverses and visits all child nodes of a given node. On each visit a callback to a given function is made.
- `VisitAllNodes()` Same as the previous method, but this method always starts at the root node so it traverses and visits all nodes in the entire tree.
- `VisitLeaves()` Traverses all child nodes of a given node and visits nodes that are leaves. On each visit a callback to a given function is made.
- `VisitAllLeaves()` Same as the previous method, but this method always starts at the root node so it traverses all nodes and visits all the leaf nodes in the entire tree.
- `FindLeftLeaf()` Traverse the tree downwards and leftwards until a leaf is found. Returns a reference to the found leaf.
- `FindRightLeaf()` Traverse the tree downwards and rightwards until a leaf is found. Returns a reference to the found leaf.
- `LeafToLeafRight()` Traverse the tree from leaf to leaf in a rightwards direction. Returns a reference to the found leaf.

A binary tree contains nodes, so I'll need to create a node class. I'll call this *BspNode*.

The *BspNode* has an `id` that auto increments on the creation of a new node, a static `minSize` that defines the minimum allowed size for a node, `height` & `width` dimensions, a position relative to the tree stored as `x` & `y`, and references to it's `parent` node, the two `children` nodes and the `tree` it belongs to. The node optionally also contains `room` data. Upon creation the node splits itself, randomly either horizontally or vertically into smaller and smaller nodes recursively until the minimum size is reached. When the minimum size is reached a room is created in the node. The nodes at the bottom of the tree that contain rooms are called leaves. A leaf can be identified by not having any children. All nodes except for the root node has a parent and a sibling. The root node can be identified by not having a parent.

The node class contains the following methods:
- `GetLevel()` A method to check the node's depth level in the tree
- `HasParent()` Checking if the node has a parent. This can be used to identify the root node when traversing the tree.
- `IsSecondChild()` Checking if the current node is the first or second child of it's parent. This can be used during traversal.
- `GetSibling()` Returns the sibling object.
- `HasRoom()` Checks if the node contains room data. This can be useful when traversing the tree and looking for rooms. Though in the current setup the only nodes with rooms are leaves and all leaf nodes contain a rooms, so checking if a node is a leaf would give the same result.
- `IsLeaf()` Checks if the node is a leaf.
- `TrySplit()` Try to split the node into two child nodes. If the node is big enough it can be splitted, if not a room is created in the node instead of splitting.
- `TrySplitHorizontal()` Try to split the node into two child nodes horizontally. Returns true if the split was a success or false if it failed.
- `TrySplitVertically()` Same as the previous mehtod, but with vertical split instead.
- `MakeRoom()` Make a new room in the current node and store a reference to the new room.

Then there's the *Room* class that actually creates the room.

It has a `x` & `y` position, `width`, `height`, a reference to the parent `node` and `area`, a 2D array of nullable bools that works just like the array in *Map*.

Upon creation it recieves the full width and height of the parent node, but some padding is added and the room is made a bit smaller to create some open spaces on the map that are not occupied by rooms.

More rules can be added to the room, such as placing items or characters inside, but for now it'l just be a rectangle of open space surrounded by walls.

And the last class to add for now is the static *Rand* class for random generation.

Rand will make use of the build-in Random class.

{% include folder_tree.html root="Roguelike" content="+Roguelike.csproj,src|+BspNode.cs|+BspTree.cs|+Game.cs|+Map.cs|+Rand.cs|+Room.cs" %}

<div class="block-title">Creating a new C# project:</div>

{% include bash_command.html bash_command="mkdir Roguelike && cd Roguelike" %}

{% include bash_command.html bash_dir="~/Roguelike" bash_command="dotnet new console --use-program-main" %}

{% include bash_command.html bash_dir="~/Roguelike" bash_command="mv src/Program.cs src/Game.cs" %}

<div class="block-title">Rand.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Shared class for random generation.
/// </summary>
static class Rand 
{
    public static Random random { get; private set; } = new Random();
    
    public static bool Percent(int i)
    {
        return (random.Next(99) < i); 
    }
}
```

<div class="block-title">Game.cs:</div>

```csharp
namespace Roguelike;

static class Game
{
    static void Main(string[] args)
    {
        Map map = new Map(96, 48);
    }
}
```

<div class="block-title">Map.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// World map.
/// </summary>
public class Map
{
    // Map size
    public readonly int width;
    public readonly int height;

    // Map data
    public BspTree tree { get; private set; }
    private bool?[,] map;

    // Constructor
    public Map(int width, int height)
    {
        this.width = width;
        this.height = height;
        this.map = new bool?[width, height];
        this.tree = new BspTree(this, width, height);
        BuildMap();
        Render();
    }

    // Build the map
    private void BuildMap() {

        // Build all rooms
        tree.VisitAllNodes(BuildRoom);
    }

    // Build room from a node
    private void BuildRoom(BspNode node)
    {
        if (node.HasRoom())
        {
            Room room = node.room;
            BuildSpace(room.x, room.y, room.width, room.height, room.area);
        }
    }

    // Transfer location to world space and carve out area
    private void BuildSpace(int worldX, int worldY, int width, int height, bool?[,] area)
    {
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                if (area[x, y] != null){ map[worldX + x, worldY + y] = area[x, y]; }
            }
        }
    }

    // Render map as ascii characters
    public void Render() {
    Console.WriteLine("GENERATED MAP " + width.ToString() + "x" + height.ToString());
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                char tileChar = '.';

                if (map[x, y] == true)
                {
                    tileChar = ' ';
                }
                else if (map[x, y] == false)
                {
                    tileChar = '#';
                }
                
                // Write char to console
                Console.Write(tileChar);
            }

            // Go to next line
            Console.Write(Environment.NewLine);
        }
    }
}
```

<div class="block-title">BspTree.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Binary space partitioning (BSP) tree for map generation.
/// </summary>
public class BspTree
{
    // Tree count, increments every time a new tree is created
    public static int count { get; private set; } = 0;

    public readonly int id;     // Tree id
    public readonly int x;      // X position on map
    public readonly int y;      // Y position on map
    public readonly int width;  
    public readonly int height; 

    // Parent
    public readonly Map map;

    // Root node
    public readonly BspNode root;

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

        // Print info for all nodes
        VisitAllNodes(NodeInfo);
    }

    
    // Print info for a given node
    private void NodeInfo(BspNode node)
    {
        Console.WriteLine("Node (" + node.id.ToString() + "), parent: " + (node.parent != null ? node.parent.id : "null") + ", sibling: " + (node.GetSibling() != null ? node.GetSibling().id : "null") + ", children[0]: " + (node.children[0] != null ? node.children[0].id : "null") + ", children[1]: " + (node.children[1] != null ? node.children[1].id : "null"));
    }

    // Visit all nodes and call callback when visiting
    public void VisitAllNodes(Action<BspNode> callback)
    {
        VisitNodes(root, callback);
    }

    // Visit current node and all child nodes and call callback method when visiting
    private void VisitNodes(BspNode node, Action<BspNode> callback)
    {
        if (node.children[0] != null) { VisitNodes(node.children[0], callback); }
        if (node.children[1] != null) { VisitNodes(node.children[1], callback); }
        callback(node);
    }

    // Visit all leaves and call callback when visiting
    public void VisitAllLeaves(Action<BspNode> callback)
    {
        VisitLeaves(root, callback);
    }

    // Traverse current node and all child nodes and call callback method when reaching the tree leaves
    private void VisitLeaves(BspNode node, Action<BspNode> callback)
    {
        if (node.children[0] != null) { VisitLeaves(node.children[0], callback); }
        if (node.children[1] != null) { VisitLeaves(node.children[1], callback); }
        if (node.children[0] == null && node.children[1] == null) { callback(node); }
    }

    // Visit left child recursively until leaf found
    public BspNode FindLeftLeaf(BspNode node)
    {
        if (node.children[0] != null) { return FindLeftLeaf(node.children[0]); }
        else{ return node; }
    }
    
    // Visit right child recursively until leaf found
    public BspNode FindRightLeaf(BspNode node)
    {
        if (node.children[1] != null) { return FindRightLeaf(node.children[1]); }
        else{ return node; }
    }

    // Find next leaf to the right of current leaf, return null if at rightmost leaf
    public BspNode LeafToLeafRight(BspNode node)
    {
        while (true)
        {
            bool moveRight = !node.IsSecondChild();
            if (node.parent == null) { return null; }
            else { node = node.parent; }
            if (node.children[1] != null && moveRight)
            {  
                node = node.children[1];
                if (node.children[0] != null) { return FindLeftLeaf(node.children[0]); }
                return node;
            }
        }

    }
}
```

<div class="block-title">BspNode.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// Binary space partitioning (BSP) node for map generation.
/// </summary>
public class BspNode
{
    // Node count, increments every time a new node is created
    public static int count { get; private set; } = 0;

    // The node splits recursively until the minSize is reached (in either dimension)
    private static int minSize = 12;

    public readonly int id;     // Node id
    public readonly int x;      // X position on the map
    public readonly int y;      // Y position on the map
    public readonly int width;
    public readonly int height;

    // Parent tree
    public readonly BspTree tree;

    // Parent node
    public BspNode parent { get; private set;}

    // Children
    public BspNode[] children = { null, null };
    
    // Node data
    public Room room { get; private set; } = null;
    
    // Constructor
    public BspNode(BspTree tree, int width, int height, int x = 0, int y = 0, BspNode parent = null)
    {
        this.id = count;
        count++;
        this.tree = tree;
        this.parent = parent;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

        // Recursivly try to split the node into smaller nodes
        TrySplit();
    }

    // Return node depth
    public int GetLevel() 
    {
        int level = 0;
        BspNode parentCheck = parent;
        while (parentCheck != null)
        {
            parentCheck = parentCheck.parent;
            level++;
        }
        return level;
    }
    
    // Return true if this node has a parent
    public bool HasParent()
    {
        if (parent != null) { return true; }
        return false;
    }
    
    // Return true if this node is the second child
    public bool IsSecondChild()
    {
        if (HasParent()) { if (parent.children[1] == this) { return true; } }
        return false;
    }
   
    // Return the sibling node if this node has a sibling, else returns null
    public BspNode GetSibling()
    {
        if (HasParent())
        {
            if (IsSecondChild()) { return parent.children[0]; }
            else { return parent.children[1]; }
        }
        return null;
    }

    // Return true if this node has a room
    public bool HasRoom()
    {
        if (room != null) { return true; }
        return false;
    }

    // Return true if this node is a leaf
    public bool IsLeaf()
    {
        if (children[0] == null && children[1] == null) { return true; }
        return false;
    }

    // Try to split the node horizontally
    private bool TrySplitHorizontal() 
    {
        int splitX = x + Rand.random.Next((int)(width * 0.25), (int)(width * 0.75));
        int widthChildLeft = splitX - x;
        int widthChildRight = (x + width) - splitX;
        if (widthChildLeft > minSize && widthChildRight > minSize)
        {
            children[0] = new BspNode(tree, widthChildLeft, height, x, y, parent: this);
            children[1] = new BspNode(tree, widthChildRight, height, splitX, y, parent: this);
            return true;
        }
        return false;
    }

    // Try to split the node vertically
    private bool TrySplitVertical()
    {
        int splitY = y + Rand.random.Next((int)(height * 0.25), (int)(height * 0.75));
        int heightChildLeft = splitY - y;
        int heightChildRight = (y + height) - splitY;
        if (heightChildLeft > minSize && heightChildRight > minSize)
        {
            children[0] = new BspNode(tree, width, heightChildLeft, x, y, parent: this);
            children[1] = new BspNode(tree, width, heightChildRight, x, splitY, parent: this);
            return true;
        }
        return false;
    }

    // Try to split the node
    private void TrySplit() 
    {
        // Set to true if node was split
        bool validSplit = false;
        
        // Decrease likelihood of splitting based on node depth
        bool trySplit = Rand.Percent(100 - Math.Min(25, (GetLevel() * 2)));

        // Randomly pick horizontal or vertical split
        bool dirHor = Rand.Percent(30);
        
        // Try to split the node
        if (trySplit)
        {
            // Try to split the node horizontally, if not possible then try vertically
            if (dirHor)
            { 
                validSplit = TrySplitHorizontal(); 
                if (!validSplit) { validSplit = TrySplitVertical(); }
            }
            
            // Try to split the node vertically, if not possible then try horizontally
            else
            {
                validSplit = TrySplitVertical(); 
                if (!validSplit) { validSplit = TrySplitHorizontal(); }
            }
        }

        // Was not able to split the node, turn the node into a room
        if (!validSplit) { MakeRoom(); }
    }

    // Make a room in this node
    private void MakeRoom()
    {
        room = new Room(this);
    }
}
```

<div class="block-title">Room.cs:</div>

```csharp
namespace Roguelike;

/// <summary>
/// A room.
/// </summary>
public class Room
{
    // The minimum size for a room (in either dimension)
    private static int minRoomSize = 5;

    public readonly int x;      // X position on the map
    public readonly int y;      // Y position on the map
    public readonly int width;
    public readonly int height;
    
    // Parent node
    public readonly BspNode node;

    // Room data
    public bool?[,] area { get; private set; }

    // Constructor
    public Room(BspNode node)
    {

        // Set padding
        int paddingVertical = Rand.random.Next(2, Math.Clamp(node.height - minRoomSize, 2, 10));
        int paddingHorizontal = Rand.random.Next(2, Math.Clamp(node.width - minRoomSize, 2, 10)); 
        int paddingTop = Rand.random.Next((int)(paddingVertical * 0.2), (int)(paddingVertical * 0.8));
        int paddingLeft = Rand.random.Next((int)(paddingHorizontal * 0.2), (int)(paddingHorizontal * 0.8));

        int width = node.width - paddingHorizontal;
        int height = node.height - paddingVertical;

        // Restrict room width/height ratio
        if (height > width) { height = Math.Min((int)(width * 8), width); }
        else { width = Math.Min((int)(height * 8), height); }

        // Set position and size
        this.node = node;
        this.x = node.x + paddingLeft;
        this.y = node.y + paddingTop;
        this.width = width;
        this.height = height;
        this.area = new bool?[width, height];

        // Generate room
        Generate();
    }
    
    // Generate room
    private void Generate() {
        for (int y = 0; y < height; y++) 
        {
            for (int x = 0; x < width; x++) 
            {
                if (x == 0 || y == 0 || x == width - 1 || y == height - 1) { area[x,y] = false; }
                else { area[x,y] = true; }
            }
        }
    }
}
```

### Conclusion
---

And that's it for the first part of the BSP dungeon generator. In a later devlog I'll add corridors between the rooms.

{% include bash_command.html bash_command="dotnet run" bash_dir="~/Roguelike" %}

[![screenshot](/img/screenshot_2024-06-07-015701.png)](/img/screenshot_2024-06-07-015701.png){:target="_blank"}

Download the source code: [roguelike-devlog2.zip](/files/roguelike-devlog2.zip){:target="_blank"}

Find the project on GitHub: [lzzrhx/Roguelike](https://github.com/lzzrhx/roguelike){:target="_blank"}
