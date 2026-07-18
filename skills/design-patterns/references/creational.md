# Creational Design Patterns

Creational patterns control **how objects are created**. They decouple a system from the specifics of object construction so that the *what* (which class) and the *how* (which constructor parameters, which lifecycle) can vary without changing client code.

Examples in this file use Python primarily, with TypeScript or Java where the static-type idiom clarifies intent.

---

## Singleton

**Intent:** Ensure a class has exactly one instance and provide a global access point to it.

**When to use:**
- A truly process-wide resource: a single application-wide logger, a single OS-level audio mixer, a single config registry loaded from disk.
- The "one instance" is an enforceable invariant — having two would cause bugs.

**When NOT to use:**
- Most of the time. Singleton is global state, and global state hurts testability, parallelism, and reasoning. The need for *one* instance and the need for *global access* are independent concerns; conflating them is what makes Singleton infamous.
- If you just want "easy access from anywhere," use **Dependency Injection** instead.
- In Python or JavaScript, a module-level value gives you Singleton semantics for free — no class needed.

**Python idiom (preferred): module-level state**

```python
# config.py
_config = None

def get_config():
    global _config
    if _config is None:
        _config = load_config_from_disk()
    return _config
```

A module is loaded once per process; `_config` is shared across all imports. This *is* a Singleton and requires no class.

**Class-based Singleton (when you must)**

```python
class Logger:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init()
        return cls._instance

    def _init(self):
        self.log_file = open("app.log", "a")
```

**Pitfalls:**
- **Hidden coupling.** Code that calls `Logger()` anywhere has an invisible dependency. Tests can't substitute it without monkey-patching.
- **Thread safety.** The naive `if _instance is None` check is racy. Use a lock, or initialize at module load time.
- **Subclassing.** Singletons resist subclassing. Combining "exactly one" with inheritance gets confusing fast.
- **Multi-process / multi-thread.** "One instance" usually means *per process*. If you fork or use multiple processes, you have N singletons.

---

## Factory Method

**Intent:** Define an interface for creating an object, but let subclasses (or a parameterized function) decide which class to instantiate.

**When to use:**
- A class needs to create objects but the concrete type depends on subclass, configuration, or runtime input.
- You want to centralize creation logic so adding a new type doesn't require touching call sites.

**When NOT to use:**
- A direct constructor call is fine. `User("Alice")` doesn't need a factory.
- Only one concrete type exists and likely always will.

**Example: parsing different document formats**

```python
from abc import ABC, abstractmethod

class Document(ABC):
    @abstractmethod
    def render(self) -> str: ...

class MarkdownDocument(Document):
    def render(self) -> str: return "...markdown..."

class HTMLDocument(Document):
    def render(self) -> str: return "...html..."

def document_from_extension(path: str) -> Document:
    ext = path.rsplit(".", 1)[-1].lower()
    if ext == "md":   return MarkdownDocument()
    if ext == "html": return HTMLDocument()
    raise ValueError(f"Unsupported extension: {ext}")
```

Client code calls `document_from_extension(...)` without knowing the concrete class. Adding a new format means editing one function.

**Class-based variant (template method + factory):**

```python
class Dialog(ABC):
    def render(self):
        button = self.create_button()   # factory method, overridden by subclass
        return f"<dialog>{button.render()}</dialog>"

    @abstractmethod
    def create_button(self) -> "Button": ...

class WindowsDialog(Dialog):
    def create_button(self): return WindowsButton()
```

**Pitfalls:**
- **Registry sprawl.** If you find yourself with a giant `if/elif` over types, consider a registry: `REGISTRY = {"md": MarkdownDocument, ...}` and `REGISTRY[ext]()`.
- **Confusion with Abstract Factory.** Factory Method creates *one* product type. Abstract Factory creates *families* of related products.

---

## Abstract Factory

**Intent:** Provide an interface for creating families of related or dependent objects without specifying their concrete classes.

**When to use:**
- The system must work with multiple "themes" or "platforms" where each requires a coordinated set of components — e.g., a UI toolkit where Buttons, Checkboxes, and Windows must all be Windows-styled together, or all macOS-styled together.

**When NOT to use:**
- Only one family exists. Skip the abstraction.
- Families share no common operations (then they aren't really related — use separate factories).

**Example: cross-platform UI**

```python
from abc import ABC, abstractmethod

class Button(ABC):
    @abstractmethod
    def render(self): ...

class Checkbox(ABC):
    @abstractmethod
    def render(self): ...

class WindowsButton(Button):
    def render(self): print("Render Windows button")

class WindowsCheckbox(Checkbox):
    def render(self): print("Render Windows checkbox")

class MacButton(Button):
    def render(self): print("Render Mac button")

class MacCheckbox(Checkbox):
    def render(self): print("Render Mac checkbox")

class UIFactory(ABC):
    @abstractmethod
    def create_button(self) -> Button: ...
    @abstractmethod
    def create_checkbox(self) -> Checkbox: ...

class WindowsFactory(UIFactory):
    def create_button(self):   return WindowsButton()
    def create_checkbox(self): return WindowsCheckbox()

class MacFactory(UIFactory):
    def create_button(self):   return MacButton()
    def create_checkbox(self): return MacCheckbox()

def build_app(factory: UIFactory):
    factory.create_button().render()
    factory.create_checkbox().render()

build_app(MacFactory())  # all Mac-styled
```

**Pitfalls:**
- **Adding a new product type is hard.** Adding `Slider` means updating every factory. The pattern optimizes for adding *families*, not products.
- **Heavyweight for small variations.** If only one method differs, consider a parameter or Strategy instead.

---

## Builder

**Intent:** Separate the construction of a complex object from its representation so the same construction process can create different representations.

**When to use:**
- An object has many optional fields, especially when many combinations are valid.
- Construction requires multiple steps and may need validation at the end.
- Telescoping constructors (`__init__(self, a, b=None, c=None, d=None, ...)`) have become unmanageable.

**When NOT to use:**
- Objects with two or three fields. Use a normal constructor or named arguments.
- In Python, **keyword arguments + dataclass defaults** solve most of what Builder solves in Java. Only reach for Builder when there's genuine multi-step construction or validation logic.

**Java-style Builder (because Java needs it most):**

```java
HttpRequest req = HttpRequest.newBuilder()
    .uri(URI.create("https://example.com"))
    .header("Accept", "application/json")
    .timeout(Duration.ofSeconds(10))
    .GET()
    .build();
```

**Python: usually a dataclass suffices**

```python
from dataclasses import dataclass, field

@dataclass
class HttpRequest:
    url: str
    method: str = "GET"
    headers: dict = field(default_factory=dict)
    timeout_seconds: float = 30.0
    body: bytes | None = None

req = HttpRequest(url="https://example.com", headers={"Accept": "application/json"})
```

**Python Builder (when validation across steps matters):**

```python
class QueryBuilder:
    def __init__(self):
        self._table = None
        self._wheres = []
        self._limit = None

    def select_from(self, table: str):
        self._table = table
        return self

    def where(self, condition: str):
        self._wheres.append(condition)
        return self

    def limit(self, n: int):
        self._limit = n
        return self

    def build(self) -> str:
        if not self._table:
            raise ValueError("Table required")
        sql = f"SELECT * FROM {self._table}"
        if self._wheres:
            sql += " WHERE " + " AND ".join(self._wheres)
        if self._limit is not None:
            sql += f" LIMIT {self._limit}"
        return sql

sql = QueryBuilder().select_from("users").where("age > 18").limit(10).build()
```

**Pitfalls:**
- **Forgetting the final `build()`.** Returning `self` from every step but never producing the product is a common bug. Some Builders use a separate `Director` to enforce the right call order.
- **Mutable Builder reused after `build()`.** Either reset internal state or make Builder one-shot.

---

## Prototype

**Intent:** Create new objects by cloning an existing prototype instead of constructing from scratch.

**When to use:**
- Construction is expensive (involves I/O, complex calculation, deep parsing) but variations are cheap.
- The set of object types isn't known at compile time — you receive an instance and need more like it.
- You need to preserve a complex configured state across many similar instances.

**When NOT to use:**
- Cheap construction. Just call the constructor.
- Objects with non-cloneable parts (open sockets, file handles, locks).

**Example:**

```python
import copy
from dataclasses import dataclass, field

@dataclass
class GameEnemy:
    species: str
    hp: int
    abilities: list[str] = field(default_factory=list)
    loot_table: dict = field(default_factory=dict)

# Build the prototype once (expensive: looked up in DB, balanced, etc.)
goblin_prototype = GameEnemy(
    species="goblin", hp=30,
    abilities=["bite", "throw rock"],
    loot_table={"gold": 5, "potion": 0.1},
)

# Spawn many cheaply
horde = [copy.deepcopy(goblin_prototype) for _ in range(100)]
horde[0].hp = 50   # boss goblin
```

**Pitfalls:**
- **Shallow vs deep copy.** `copy.copy` shares nested mutable state across clones — usually a bug. Default to `copy.deepcopy` unless you know shared state is intended.
- **`__deepcopy__` for special cases.** If your object holds non-copyable resources, implement `__deepcopy__` to handle them explicitly.

---

## Object Pool

**Intent:** Maintain a pool of reusable instances so clients can check out and return objects instead of creating and destroying them.

**When to use:**
- Object creation or destruction is genuinely expensive: database connections, threads, network sockets, large buffers.
- Demand is bursty but bounded — pooling caps resource use.

**When NOT to use:**
- Object construction is cheap (almost everything in modern languages with good GCs).
- Premature optimization. Profile first; pool only when measurements justify it.

**Example: simple connection pool**

```python
from contextlib import contextmanager
from queue import Queue, Empty

class ConnectionPool:
    def __init__(self, factory, size: int):
        self._pool = Queue(maxsize=size)
        for _ in range(size):
            self._pool.put(factory())

    @contextmanager
    def acquire(self, timeout: float = 5.0):
        try:
            conn = self._pool.get(timeout=timeout)
        except Empty:
            raise RuntimeError("Pool exhausted")
        try:
            yield conn
        finally:
            self._pool.put(conn)

pool = ConnectionPool(lambda: open_db_connection(), size=10)
with pool.acquire() as conn:
    conn.execute("SELECT 1")
```

**Pitfalls:**
- **Leaked checkouts.** Forgetting to return an object to the pool drains it. Use a context manager (Python `with`), `try/finally`, or RAII (C++/Rust) to guarantee return.
- **Stale state.** Pooled objects must be reset between uses. A pooled DB connection might still have an open transaction from the last user.
- **Pool size tuning.** Too small → contention; too large → resource waste. Make it configurable.

---

## Lazy Initialization

**Intent:** Defer expensive object creation until the object is first accessed.

**When to use:**
- An object may not be used in every code path, and constructing it has cost (I/O, CPU, memory).
- Initialization order or circular dependencies make eager construction impossible.

**When NOT to use:**
- The object is always used immediately. Lazy adds branching without payoff.
- The expense is in *use*, not construction. Lazy initialization helps only if construction itself is the cost.

**Python idiom: `functools.cached_property`**

```python
from functools import cached_property

class Report:
    def __init__(self, source):
        self.source = source

    @cached_property
    def parsed_data(self):
        print("Parsing... (only prints once)")
        return expensive_parse(self.source)

r = Report("big_file.csv")
r.parsed_data   # parses now
r.parsed_data   # returns cached value, no parse
```

**Manual lazy init:**

```python
class Service:
    def __init__(self):
        self._client = None

    @property
    def client(self):
        if self._client is None:
            self._client = expensive_connect()
        return self._client
```

**Pitfalls:**
- **Thread safety.** The check-and-create dance is racy under threads. Use a lock, or initialize eagerly in a thread-safe construction phase.
- **Exception hiding.** If lazy init throws, the error surfaces at first *use*, far from construction — making debugging harder. Document this.
- **Caching forever.** `cached_property` never re-runs. If the source can change, you need explicit invalidation, not lazy init.

---

## Choosing among creational patterns

| Question | Pattern |
|---|---|
| "How do I ensure one instance?" | Singleton (sparingly) — or DI |
| "How do I decide *which class* to make?" | Factory Method |
| "How do I make a *coordinated set* of objects?" | Abstract Factory |
| "How do I construct an object with many parts/options?" | Builder |
| "How do I make a *copy* of a configured object?" | Prototype |
| "How do I *reuse* expensive instances?" | Object Pool |
| "How do I *defer* creation until needed?" | Lazy Initialization |
