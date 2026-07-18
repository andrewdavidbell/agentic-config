# Structural Design Patterns

Structural patterns describe **how classes and objects compose** into larger structures while keeping those structures flexible and efficient.

---

## Adapter

**Intent:** Convert the interface of a class into another interface clients expect, letting classes work together that couldn't otherwise because of incompatible interfaces.

**When to use:**
- You're integrating a third-party library whose API doesn't match your codebase's conventions.
- You're replacing a legacy implementation with a new one and need to keep old call sites working.
- Two parts of a system have evolved different interfaces for the same conceptual operation.

**When NOT to use:**
- You own both sides. Just fix the interface — don't add a permanent translation layer.

**Example: adapting a legacy payment API**

```python
# Modern interface our app expects:
class PaymentProcessor:
    def charge(self, amount_cents: int, currency: str, token: str) -> str:
        """Returns a transaction ID."""
        ...

# Legacy third-party SDK we can't modify:
class LegacyGateway:
    def process_payment(self, dollars: float, card_token: str) -> dict:
        return {"txn_id": "...", "status": "OK"}

# Adapter wraps the legacy gateway and exposes the modern interface:
class LegacyGatewayAdapter(PaymentProcessor):
    def __init__(self, legacy: LegacyGateway):
        self._legacy = legacy

    def charge(self, amount_cents: int, currency: str, token: str) -> str:
        if currency != "USD":
            raise ValueError("Legacy gateway supports USD only")
        result = self._legacy.process_payment(dollars=amount_cents / 100, card_token=token)
        if result["status"] != "OK":
            raise RuntimeError("Payment failed")
        return result["txn_id"]
```

**Variants:**
- **Object Adapter** (above) — adapter holds an instance of the adaptee. Most common.
- **Class Adapter** — adapter inherits from both interfaces. Possible in languages with multiple inheritance; usually avoided.

**Pitfalls:**
- **Lossy translation.** If the two interfaces differ in capability (e.g., legacy doesn't support multi-currency), the adapter must either reject those calls or fabricate behavior — both are problems.
- **Adapter chains.** Adapter → Adapter → Adapter is a sign the design is wrong. Collapse layers.

---

## Decorator

**Intent:** Attach additional responsibilities to an object dynamically. Decorators provide a flexible alternative to subclassing for extending functionality.

**When to use:**
- You want to add behavior (logging, caching, validation, encryption) without modifying the underlying object or class.
- Behaviors should be combinable in any order: `Logged(Cached(Authenticated(handler)))`.

**When NOT to use:**
- A single subclass would do. Decorator earns its keep when *combinations* matter.
- The wrapped object's interface is small and stable; otherwise every decorator must implement many pass-through methods.

**Note:** The GoF *Decorator pattern* (wrapping objects) is different from Python's `@decorator` *syntax* (wrapping functions/classes). Python's syntax is a related idea but a narrower one.

**Example: HTTP handler decorators**

```python
from abc import ABC, abstractmethod

class Handler(ABC):
    @abstractmethod
    def handle(self, request) -> str: ...

class CoreHandler(Handler):
    def handle(self, request) -> str:
        return f"OK: {request}"

# Decorator base — same interface as Handler, holds a Handler.
class HandlerDecorator(Handler):
    def __init__(self, wrapped: Handler):
        self._wrapped = wrapped

    def handle(self, request) -> str:
        return self._wrapped.handle(request)

class LoggingHandler(HandlerDecorator):
    def handle(self, request) -> str:
        print(f"-> {request}")
        result = super().handle(request)
        print(f"<- {result}")
        return result

class CachingHandler(HandlerDecorator):
    def __init__(self, wrapped):
        super().__init__(wrapped)
        self._cache = {}

    def handle(self, request) -> str:
        if request not in self._cache:
            self._cache[request] = super().handle(request)
        return self._cache[request]

handler = LoggingHandler(CachingHandler(CoreHandler()))
handler.handle("/users/1")
handler.handle("/users/1")  # cache hit; logging still wraps it
```

**Pitfalls:**
- **Order matters.** `Logged(Cached(...))` logs every call, including cache hits. `Cached(Logged(...))` skips logging on hits. Be deliberate.
- **Identity confusion.** `isinstance(decorated, CoreHandler)` is False. If anyone needs to "see through" the wrapping, expose `__wrapped__` (and use `functools.wraps` for function decorators).
- **Interface drift.** Adding a method to the base interface means updating every decorator's pass-through.

---

## Facade

**Intent:** Provide a unified, high-level interface to a set of interfaces in a subsystem, making the subsystem easier to use.

**When to use:**
- A subsystem has many moving parts but clients only need the common workflows.
- You want to decouple clients from the messy internals of a library.
- You're presenting a clean API over legacy code without rewriting it.

**When NOT to use:**
- The subsystem already has a clean, narrow interface — adding a Facade just adds a layer.
- Clients legitimately need fine-grained control. Don't hide capability they need.

**Example: a Facade over a video-conversion pipeline**

```python
# Subsystem (each piece is useful on its own to advanced users):
class Demuxer:
    def demux(self, file): ...

class Decoder:
    def decode(self, stream): ...

class Resizer:
    def resize(self, frames, w, h): ...

class Encoder:
    def encode(self, frames, codec): ...

class Muxer:
    def mux(self, encoded, container): ...

# Facade: one call covers the 90% case.
class VideoConverter:
    def __init__(self):
        self.demuxer = Demuxer()
        self.decoder = Decoder()
        self.resizer = Resizer()
        self.encoder = Encoder()
        self.muxer   = Muxer()

    def convert(self, input_path: str, output_path: str,
                width: int, height: int, codec: str = "h264"):
        stream  = self.demuxer.demux(input_path)
        frames  = self.decoder.decode(stream)
        resized = self.resizer.resize(frames, width, height)
        encoded = self.encoder.encode(resized, codec)
        self.muxer.mux(encoded, output_path)
```

A user who needs unusual control still has access to the subsystem; the Facade just makes the common path effortless.

**Pitfalls:**
- **God facade.** If the Facade grows to expose everything, it stops being a Facade and becomes a leaky abstraction. Keep it focused on common workflows.
- **Coupling clients to the Facade.** If the Facade itself becomes brittle (changes break everyone), version it carefully.

---

## Composite

**Intent:** Compose objects into tree structures to represent part-whole hierarchies. Composite lets clients treat individual objects and compositions uniformly.

**When to use:**
- Your data forms a tree: file systems, GUI widgets, organization charts, parsed expressions, scene graphs.
- Clients should call the same method on a leaf and on a group of leaves.

**When NOT to use:**
- The data isn't actually tree-shaped. Forcing it loses information.
- Leaves and composites have substantially different operations that don't make sense to unify.

**Example: filesystem nodes**

```python
from abc import ABC, abstractmethod

class FSNode(ABC):
    def __init__(self, name: str):
        self.name = name

    @abstractmethod
    def size(self) -> int: ...

class File(FSNode):
    def __init__(self, name: str, size_bytes: int):
        super().__init__(name)
        self._size = size_bytes

    def size(self) -> int:
        return self._size

class Directory(FSNode):
    def __init__(self, name: str):
        super().__init__(name)
        self.children: list[FSNode] = []

    def add(self, node: FSNode):
        self.children.append(node)

    def size(self) -> int:
        return sum(child.size() for child in self.children)

root = Directory("root")
root.add(File("a.txt", 100))
sub = Directory("sub")
sub.add(File("b.txt", 200))
root.add(sub)

print(root.size())  # 300 — uniform interface across files and dirs
```

**Pitfalls:**
- **Leaf-only operations on composites.** What does `read()` mean on a Directory? Either define a sensible composite behavior or design the interface to reflect the difference (often by splitting the abstract type).
- **Cycles.** A tree assumes no cycles. If a Composite can contain its ancestor, you have a graph problem — methods like `size()` infinite-loop.
- **Parent pointers.** Often needed for navigation (`node.parent.children`) but they add maintenance overhead and break tree immutability.

---

## Proxy

**Intent:** Provide a surrogate or placeholder for another object to control access to it.

**When to use:**
- **Virtual Proxy** — delay creation of an expensive object until needed.
- **Protection Proxy** — enforce access control (auth/role checks) before forwarding calls.
- **Remote Proxy** — local stand-in for an object that lives in another process or machine (RPC clients).
- **Caching Proxy** — cache expensive results transparently.
- **Logging / Smart Reference** — add bookkeeping (refcounts, audit trail) around access.

**When NOT to use:**
- The "wrapping" needed is just adding behavior, not controlling access — that's **Decorator**.
- You can solve it with a one-line wrapper function.

**Example: caching proxy for an expensive API**

```python
from abc import ABC, abstractmethod

class WeatherService(ABC):
    @abstractmethod
    def forecast(self, city: str) -> dict: ...

class RealWeatherService(WeatherService):
    def forecast(self, city: str) -> dict:
        # Imagine an HTTP call costing 200ms.
        return fetch_remote(city)

class CachingWeatherProxy(WeatherService):
    def __init__(self, real: WeatherService, ttl_seconds: int = 60):
        self._real = real
        self._ttl = ttl_seconds
        self._cache: dict[str, tuple[float, dict]] = {}

    def forecast(self, city: str) -> dict:
        import time
        now = time.time()
        cached = self._cache.get(city)
        if cached and now - cached[0] < self._ttl:
            return cached[1]
        result = self._real.forecast(city)
        self._cache[city] = (now, result)
        return result

service: WeatherService = CachingWeatherProxy(RealWeatherService())
service.forecast("Melbourne")  # hits remote
service.forecast("Melbourne")  # cached
```

**Proxy vs Decorator vs Adapter (the perennial confusion):**

| Pattern | Purpose | Interface |
|---|---|---|
| **Adapter** | Change incompatible interface to expected one | Different → expected |
| **Decorator** | Add responsibilities to an object | Same as wrapped, with extra behavior |
| **Proxy** | Control access to an object | Same as wrapped, with access mediation |

The structural code can look identical; the *intent* differs.

**Pitfalls:**
- **Transparency illusion.** A "transparent" proxy still differs from the real object (latency, identity, error modes). Be honest about that in the API.
- **Lifetime mismatch.** A proxy may outlive the real object (e.g., disconnected remote). Handle null/dead targets explicitly.

---

## Bridge

**Intent:** Decouple an abstraction from its implementation so the two can vary independently.

**When to use:**
- Cartesian explosion: `N` abstractions × `M` implementations would mean `N × M` classes via inheritance. Bridge collapses this to `N + M`.
- A class hierarchy is splitting along two independent axes (e.g., "shape type" × "renderer").

**When NOT to use:**
- You only have one implementation. Adding a Bridge is speculative.

**Example: shapes × rendering APIs**

```python
from abc import ABC, abstractmethod

# Implementation side — varies independently.
class Renderer(ABC):
    @abstractmethod
    def draw_circle(self, x, y, r): ...
    @abstractmethod
    def draw_rect(self, x, y, w, h): ...

class SVGRenderer(Renderer):
    def draw_circle(self, x, y, r): print(f"<circle cx={x} cy={y} r={r}/>")
    def draw_rect(self, x, y, w, h): print(f"<rect x={x} y={y} w={w} h={h}/>")

class CanvasRenderer(Renderer):
    def draw_circle(self, x, y, r): print(f"ctx.arc({x},{y},{r})")
    def draw_rect(self, x, y, w, h): print(f"ctx.rect({x},{y},{w},{h})")

# Abstraction side — also varies independently. Holds a Renderer.
class Shape(ABC):
    def __init__(self, renderer: Renderer):
        self.renderer = renderer

    @abstractmethod
    def draw(self): ...

class Circle(Shape):
    def __init__(self, renderer, x, y, r):
        super().__init__(renderer)
        self.x, self.y, self.r = x, y, r

    def draw(self):
        self.renderer.draw_circle(self.x, self.y, self.r)

class Rectangle(Shape):
    def __init__(self, renderer, x, y, w, h):
        super().__init__(renderer)
        self.x, self.y, self.w, self.h = x, y, w, h

    def draw(self):
        self.renderer.draw_rect(self.x, self.y, self.w, self.h)

# 2 shapes × 2 renderers = 4 combinations, only 4 classes (not 4 subclasses each).
Circle(SVGRenderer(), 10, 10, 5).draw()
Rectangle(CanvasRenderer(), 0, 0, 100, 50).draw()
```

**Bridge vs Strategy:** Both compose an object that varies behavior. Strategy is usually short-lived (passed in for one operation) and the abstraction doesn't have a parallel hierarchy. Bridge is structural — both sides are class hierarchies that evolve.

**Pitfalls:**
- **Over-engineering.** Only valuable when both axes genuinely vary. If you have one renderer and "might add another someday," that's YAGNI.

---

## Flyweight

**Intent:** Use sharing to support large numbers of fine-grained objects efficiently.

**When to use:**
- You have *many* (millions) similar objects whose memory cost matters.
- Most of each object's state is *intrinsic* (shared across instances), and only a small part is *extrinsic* (unique per use).
- Examples: glyphs in a text editor, particles in a simulation, tiles in a tilemap, tree species in a forest renderer.

**When NOT to use:**
- Object count is modest (thousands, not millions).
- Most state is unique. Sharing nothing buys nothing.

**Example: rendering a forest with millions of trees**

```python
class TreeType:  # Flyweight — shared across many trees.
    def __init__(self, species: str, mesh, texture):
        self.species = species
        self.mesh = mesh           # heavyweight: 3D model data
        self.texture = texture     # heavyweight: image data

    def draw(self, x, y, z):
        # Render the tree at (x, y, z) using shared mesh/texture.
        ...

class TreeTypeFactory:
    _types: dict[str, TreeType] = {}

    @classmethod
    def get(cls, species: str, mesh, texture) -> TreeType:
        if species not in cls._types:
            cls._types[species] = TreeType(species, mesh, texture)
        return cls._types[species]

class Tree:  # Lightweight — millions of these.
    __slots__ = ("x", "y", "z", "type")
    def __init__(self, x, y, z, type: TreeType):
        self.x, self.y, self.z, self.type = x, y, z, type

    def draw(self):
        self.type.draw(self.x, self.y, self.z)

# A million trees share a handful of TreeTypes.
oak_type = TreeTypeFactory.get("oak", oak_mesh, oak_tex)
forest = [Tree(random_pos(), random_pos(), 0, oak_type) for _ in range(1_000_000)]
```

Without Flyweight, each Tree would carry its own mesh/texture (gigabytes). With Flyweight, total memory is dominated by the per-tree coordinates.

**Pitfalls:**
- **Mutable shared state.** Flyweights must be immutable (or treated as such). Mutating one breaks every user.
- **Premature application.** Flyweight only pays off at scale. Profile memory first.
- **Identity vs equality.** Shared instances mean `tree1.type is tree2.type` will be true for same-species trees. Code that distinguishes by identity may break.

---

## Choosing among structural patterns

| Question | Pattern |
|---|---|
| "How do I make incompatible interfaces work together?" | Adapter |
| "How do I add behavior without subclassing?" | Decorator |
| "How do I simplify a complex subsystem?" | Facade |
| "How do I treat groups of objects like single objects?" | Composite |
| "How do I control access to an object?" | Proxy |
| "How do I let abstraction and implementation vary independently?" | Bridge |
| "How do I support huge numbers of similar objects?" | Flyweight |
