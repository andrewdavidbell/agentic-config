# Behavioral Design Patterns

Behavioral patterns describe **how objects interact and distribute responsibility**. They focus on communication patterns between objects and the assignment of duties.

---

## Observer

**Intent:** Define a one-to-many dependency between objects so that when one object changes state, all its dependents are notified and updated automatically.

**When to use:**
- An object's state change must propagate to an unknown number of dependents.
- The dependents don't all want to know each other (loose coupling).
- Classic uses: event systems, model-view binding, pub/sub, reactive UIs.

**When NOT to use:**
- One-to-one notification with a fixed recipient — just call the method.
- The "update" needs synchronous ordering guarantees across observers — Observer makes ordering non-obvious.

**Example: stock price ticker**

```python
from abc import ABC, abstractmethod

class Observer(ABC):
    @abstractmethod
    def update(self, symbol: str, price: float): ...

class Stock:
    def __init__(self, symbol: str):
        self.symbol = symbol
        self._price = 0.0
        self._observers: list[Observer] = []

    def subscribe(self, obs: Observer):
        self._observers.append(obs)

    def unsubscribe(self, obs: Observer):
        self._observers.remove(obs)

    @property
    def price(self) -> float:
        return self._price

    @price.setter
    def price(self, value: float):
        self._price = value
        for obs in self._observers:
            obs.update(self.symbol, value)

class PriceLogger(Observer):
    def update(self, symbol, price):
        print(f"LOG: {symbol} = ${price:.2f}")

class AlertingObserver(Observer):
    def __init__(self, threshold):
        self.threshold = threshold
    def update(self, symbol, price):
        if price > self.threshold:
            print(f"ALERT: {symbol} crossed ${self.threshold}")

stock = Stock("ACME")
stock.subscribe(PriceLogger())
stock.subscribe(AlertingObserver(threshold=100))

stock.price = 95.5    # LOG only
stock.price = 110.0   # LOG and ALERT
```

**Variants:**
- **Push** (above) — subject sends data to observers.
- **Pull** — subject notifies "something changed" and observers query for what they need.

**Pitfalls:**
- **Memory leaks.** Observers held by long-lived subjects keep observers alive. Always provide `unsubscribe`, and consider weak references.
- **Cascade updates.** Observer A updates Subject B, which notifies Observer C, which updates Subject A... debugging is awful. Watch for cycles.
- **Synchronous notification under contention.** A slow observer blocks the subject. For high-throughput cases, push events to a queue.
- **Notification during iteration.** If an observer subscribes/unsubscribes inside `update()`, you mutate the list mid-iteration. Iterate over a copy.

---

## Strategy

**Intent:** Define a family of algorithms, encapsulate each one, and make them interchangeable. Strategy lets the algorithm vary independently from clients that use it.

**When to use:**
- You have multiple ways to do the same thing (different sort orders, payment methods, compression algorithms, pricing rules) and want to swap them at runtime.
- A class has a method full of conditional branches that select algorithm by type/flag.

**When NOT to use:**
- There's only ever one algorithm. Don't add an interface for theoretical extension.
- In languages with first-class functions, often you just pass the function — no Strategy class needed.

**Example: sorting with pluggable comparators (in Python, use a function)**

```python
# Strategy as a first-class function — the Pythonic way.
items = [{"name": "b", "price": 5}, {"name": "a", "price": 10}]

by_name  = sorted(items, key=lambda x: x["name"])
by_price = sorted(items, key=lambda x: x["price"])
```

**Class-based Strategy (for richer strategies with state):**

```python
from abc import ABC, abstractmethod

class ShippingStrategy(ABC):
    @abstractmethod
    def calculate(self, weight_kg: float, distance_km: float) -> float: ...

class GroundShipping(ShippingStrategy):
    def calculate(self, weight_kg, distance_km):
        return weight_kg * 0.5 + distance_km * 0.1

class AirShipping(ShippingStrategy):
    def calculate(self, weight_kg, distance_km):
        return weight_kg * 2.0 + distance_km * 0.5

class OvernightShipping(ShippingStrategy):
    def calculate(self, weight_kg, distance_km):
        return weight_kg * 5.0 + distance_km * 1.0 + 20.0  # surcharge

class Order:
    def __init__(self, weight_kg, distance_km, strategy: ShippingStrategy):
        self.weight_kg = weight_kg
        self.distance_km = distance_km
        self.strategy = strategy

    def shipping_cost(self) -> float:
        return self.strategy.calculate(self.weight_kg, self.distance_km)

order = Order(2.0, 500.0, AirShipping())
print(order.shipping_cost())
order.strategy = OvernightShipping()  # swap at runtime
```

**Pitfalls:**
- **Strategy vs State.** Strategy: client picks. State: object picks based on internal state. Same structure, different driver.
- **Parameter creep.** When strategies need wildly different inputs, the common interface becomes lowest-common-denominator. Consider passing a richer context object.

---

## Command

**Intent:** Encapsulate a request as an object, thereby letting you parameterize clients with different requests, queue or log requests, and support undoable operations.

**When to use:**
- You need undo/redo.
- You're building a job queue or task scheduler.
- You're recording macros or replays.
- You want to decouple the invoker from the executor (UI button → arbitrary action).

**When NOT to use:**
- A direct method call suffices. Don't wrap every call in a Command "just in case."

**Example: text editor with undo**

```python
from abc import ABC, abstractmethod

class Command(ABC):
    @abstractmethod
    def execute(self): ...
    @abstractmethod
    def undo(self): ...

class TextEditor:
    def __init__(self):
        self.text = ""
        self._history: list[Command] = []
        self._redo: list[Command] = []

    def run(self, cmd: Command):
        cmd.execute()
        self._history.append(cmd)
        self._redo.clear()  # any new command invalidates redo

    def undo(self):
        if self._history:
            cmd = self._history.pop()
            cmd.undo()
            self._redo.append(cmd)

    def redo(self):
        if self._redo:
            cmd = self._redo.pop()
            cmd.execute()
            self._history.append(cmd)

class InsertText(Command):
    def __init__(self, editor: TextEditor, text: str, position: int):
        self.editor = editor
        self.text = text
        self.position = position

    def execute(self):
        e = self.editor
        e.text = e.text[:self.position] + self.text + e.text[self.position:]

    def undo(self):
        e = self.editor
        end = self.position + len(self.text)
        e.text = e.text[:self.position] + e.text[end:]

editor = TextEditor()
editor.run(InsertText(editor, "Hello", 0))
editor.run(InsertText(editor, ", world!", 5))
print(editor.text)  # "Hello, world!"
editor.undo()
print(editor.text)  # "Hello"
editor.redo()
print(editor.text)  # "Hello, world!"
```

**Pitfalls:**
- **Memory bloat.** Every command keeps state for undo. For large operations, consider snapshots (Memento) instead of inverse operations.
- **Undo correctness.** Inverting an operation is easy when state is local; hard when commands have side effects on shared state. Test thoroughly.
- **Queue semantics.** Serializing a Command for later execution requires the command to be self-contained (no closures over transient state).

---

## Chain of Responsibility

**Intent:** Pass a request along a chain of handlers. Each handler decides either to process the request or pass it to the next handler.

**When to use:**
- A request might be handled by one of several handlers, and the sender doesn't need to know which.
- The set of handlers is configured at runtime (middleware stacks, event filters, support escalation).

**When NOT to use:**
- The handler is always known. Just call it.
- The chain can fail to handle the request and you have no fallback — silent drops are dangerous.

**Example: HTTP middleware**

```python
from abc import ABC, abstractmethod

class Handler(ABC):
    def __init__(self):
        self._next: Handler | None = None

    def then(self, h: "Handler") -> "Handler":
        self._next = h
        return h  # so you can chain: a.then(b).then(c)

    def handle(self, request):
        if self._next:
            return self._next.handle(request)
        return None

class AuthHandler(Handler):
    def handle(self, request):
        if "auth_token" not in request:
            return {"status": 401, "error": "unauthorized"}
        return super().handle(request)

class RateLimitHandler(Handler):
    def __init__(self, max_per_min=60):
        super().__init__()
        self._count = 0
        self._max = max_per_min

    def handle(self, request):
        self._count += 1
        if self._count > self._max:
            return {"status": 429, "error": "rate limited"}
        return super().handle(request)

class CoreHandler(Handler):
    def handle(self, request):
        return {"status": 200, "body": f"hello, {request['user']}"}

pipeline = AuthHandler()
pipeline.then(RateLimitHandler()).then(CoreHandler())

print(pipeline.handle({"user": "alice", "auth_token": "xyz"}))
print(pipeline.handle({"user": "bob"}))  # 401
```

**Pitfalls:**
- **Unhandled request.** If no handler claims it, the request silently disappears. Always have a default handler or return-None semantics that callers check.
- **Order dependence.** AuthHandler before RateLimit means unauthenticated users still consume rate-limit slots. Order is part of the design.
- **Implicit control flow.** Hard to debug because behavior depends on chain configuration, not just code. Log which handler processed what.

---

## Template Method

**Intent:** Define the skeleton of an algorithm in a base class, deferring some steps to subclasses. Template Method lets subclasses redefine certain steps without changing the algorithm's structure.

**When to use:**
- Multiple classes share an algorithm structure but differ in specific steps.
- You want to enforce an invariant about the order of operations (subclasses can't reorder).

**When NOT to use:**
- The "algorithm" is trivial — just pass a function (Strategy via callback).
- Steps vary independently with high combinatorial freedom — composition beats inheritance.

**Example: report generation pipeline**

```python
from abc import ABC, abstractmethod

class ReportGenerator(ABC):
    # Template method — concrete, defines the algorithm.
    def generate(self, output_path: str):
        data = self._fetch_data()
        cleaned = self._clean(data)
        formatted = self._format(cleaned)
        self._write(formatted, output_path)
        self._on_complete()   # optional hook

    @abstractmethod
    def _fetch_data(self): ...

    @abstractmethod
    def _format(self, data): ...

    # Default implementation; subclasses MAY override.
    def _clean(self, data):
        return [row for row in data if row]

    def _write(self, content, path):
        with open(path, "w") as f:
            f.write(content)

    def _on_complete(self):
        pass

class SalesReport(ReportGenerator):
    def _fetch_data(self):
        return query_db("SELECT * FROM sales")

    def _format(self, data):
        return "\n".join(f"{r['date']}: ${r['amount']}" for r in data)

    def _on_complete(self):
        notify_team("Sales report ready")

class InventoryReport(ReportGenerator):
    def _fetch_data(self):
        return query_inventory_api()

    def _format(self, data):
        return generate_html_table(data)
```

**Pitfalls:**
- **Fragile base class.** Changes to the template ripple to every subclass. Document which methods are hooks (overridable) vs invariants (do not override).
- **Reverse dependency.** Base class calls subclass methods (the Hollywood principle: "don't call us, we'll call you"). New developers find this surprising.
- **Constructor traps.** Calling overridable methods from a constructor is dangerous — the subclass isn't initialized yet.

---

## Iterator

**Intent:** Provide a way to access the elements of an aggregate object sequentially without exposing its underlying representation.

**When to use:**
- You're building a collection and want clients to traverse it without knowing the internal structure.
- You need multiple simultaneous traversals (each iterator has independent state).
- You're traversing lazily over a possibly infinite or expensive sequence.

**When NOT to use:**
- The language already gives you iteration over native collections — don't reinvent it.

**Python idiom: generators (almost always preferred)**

```python
def fibonacci():
    a, b = 0, 1
    while True:
        yield a
        a, b = b, a + b

# Use it:
import itertools
print(list(itertools.islice(fibonacci(), 10)))
# [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
```

**Custom iterable class:**

```python
class Tree:
    def __init__(self, value, children=None):
        self.value = value
        self.children = children or []

    def __iter__(self):
        # Depth-first traversal as a generator.
        yield self.value
        for child in self.children:
            yield from child

root = Tree(1, [Tree(2, [Tree(4), Tree(5)]), Tree(3)])
print(list(root))  # [1, 2, 4, 5, 3]
```

**Classical Iterator (Java-style — rarely needed in Python):**

```python
class Iterator(ABC):
    @abstractmethod
    def has_next(self) -> bool: ...
    @abstractmethod
    def next(self): ...
```

**Pitfalls:**
- **Mutation during iteration.** Modifying the underlying collection while an iterator is live is almost always a bug; most languages raise or behave unpredictably.
- **Re-iteration cost.** A generator is single-use. Calling `iter()` again on the source must yield a fresh one. Document whether your iterable is single-pass or reusable.
- **Resource cleanup.** If iteration holds a file/cursor, ensure it's released when iteration stops early (use `try/finally` or context managers).

---

## State

**Intent:** Allow an object to alter its behavior when its internal state changes. The object will appear to change its class.

**When to use:**
- Behavior depends on state, and you have a method full of `if self.state == "A": ... elif self.state == "B": ...`.
- The state machine is non-trivial (3+ states with transitions).
- States have their own data and methods that don't apply to other states.

**When NOT to use:**
- A simple boolean flag suffices.
- The state never changes — that's just polymorphism.

**Example: TCP connection state machine**

```python
from abc import ABC, abstractmethod

class TCPState(ABC):
    @abstractmethod
    def open(self, conn): ...
    @abstractmethod
    def close(self, conn): ...
    @abstractmethod
    def send(self, conn, data): ...

class ClosedState(TCPState):
    def open(self, conn):
        print("Opening connection...")
        conn.state = EstablishedState()
    def close(self, conn):
        print("Already closed.")
    def send(self, conn, data):
        raise RuntimeError("Cannot send on closed connection")

class EstablishedState(TCPState):
    def open(self, conn):
        print("Already open.")
    def close(self, conn):
        print("Closing connection...")
        conn.state = ClosedState()
    def send(self, conn, data):
        print(f"Sending: {data}")

class TCPConnection:
    def __init__(self):
        self.state: TCPState = ClosedState()

    def open(self):  self.state.open(self)
    def close(self): self.state.close(self)
    def send(self, data): self.state.send(self, data)

conn = TCPConnection()
conn.open()
conn.send("hello")
conn.close()
conn.send("hi again")   # RuntimeError
```

**State vs Strategy:** Both delegate to a polymorphic object. With **Strategy**, the *client* chooses and swaps. With **State**, the *object itself* transitions, often triggered by methods that observe and update internal state.

**Pitfalls:**
- **State explosion.** Many states with many transitions get unwieldy fast. Consider a table-driven state machine (data, not classes) for large cases.
- **Where do transitions live?** Either in the State objects (each state knows what's next) or in the context (central transition table). Pick one and be consistent.
- **Shared data.** If states need access to context data, pass `conn` (as above) or hold a back-reference.

---

## Mediator

**Intent:** Define an object that encapsulates how a set of objects interact. Mediator promotes loose coupling by keeping objects from referring to each other explicitly.

**When to use:**
- A set of objects communicate in complex, well-defined ways and you want to centralize the coordination logic.
- Classic example: a dialog window where checkboxes, dropdowns, and text fields enable/disable each other based on state.

**When NOT to use:**
- The interactions are simple and few. A Mediator becomes a god object if it absorbs too much logic.
- The components don't need to talk to each other at all.

**Example: chat room (the canonical Mediator)**

```python
class ChatRoom:
    def __init__(self):
        self._members: dict[str, "User"] = {}

    def join(self, user: "User"):
        self._members[user.name] = user
        user.room = self

    def send(self, sender: "User", message: str, to: str | None = None):
        if to:
            self._members[to].receive(sender.name, message)
        else:
            for name, member in self._members.items():
                if name != sender.name:
                    member.receive(sender.name, message)

class User:
    def __init__(self, name: str):
        self.name = name
        self.room: ChatRoom | None = None

    def send(self, message: str, to: str | None = None):
        self.room.send(self, message, to)

    def receive(self, sender: str, message: str):
        print(f"[{self.name}] {sender}: {message}")

room = ChatRoom()
alice, bob, carol = User("alice"), User("bob"), User("carol")
for u in (alice, bob, carol): room.join(u)

alice.send("hello everyone")
bob.send("hi alice", to="alice")
```

Users know about the room, not about each other. Adding a new user, kicking a user, filtering, or logging all centralize in the Mediator.

**Pitfalls:**
- **God object.** The Mediator can grow into a monster that knows too much about every component. Split it when this happens.
- **Hidden coupling.** Components are decoupled from each other but tightly coupled to the Mediator's API. Make that API stable and small.

---

## Memento

**Intent:** Without violating encapsulation, capture and externalize an object's internal state so the object can be restored to this state later.

**When to use:**
- You need snapshot-based undo (Command's per-operation inverse isn't feasible).
- You need to save/restore application state (checkpoints, save games).
- You need transactional behavior — try a change, roll back if it doesn't work.

**When NOT to use:**
- The object's state is huge and snapshots are expensive. Consider command-based undo.
- The state can simply be re-derived.

**Example: text editor snapshots**

```python
class EditorMemento:
    def __init__(self, content: str, cursor: int):
        # Immutable from the outside.
        self._content = content
        self._cursor = cursor

    def restore(self, editor: "Editor"):
        editor._content = self._content
        editor._cursor = self._cursor

class Editor:
    def __init__(self):
        self._content = ""
        self._cursor = 0

    @property
    def content(self) -> str:
        return self._content

    def type(self, text: str):
        self._content = self._content[:self._cursor] + text + self._content[self._cursor:]
        self._cursor += len(text)

    def snapshot(self) -> EditorMemento:
        return EditorMemento(self._content, self._cursor)

class History:
    def __init__(self):
        self._stack: list[EditorMemento] = []
    def save(self, m: EditorMemento): self._stack.append(m)
    def undo(self, editor: Editor):
        if self._stack:
            self._stack.pop().restore(editor)

editor = Editor()
history = History()
editor.type("Hello")
history.save(editor.snapshot())
editor.type(", world")
history.undo(editor)
print(editor.content)  # "Hello"
```

**Pitfalls:**
- **Encapsulation leak.** The Memento has access to internals. Keep it tightly scoped — only the originator should restore.
- **Cost.** Snapshotting big state every keystroke is expensive. Consider deltas or compression.
- **Serialization.** If you persist Mementos, version them — old snapshots must still load after the class evolves.

---

## Visitor

**Intent:** Represent an operation to be performed on the elements of an object structure. Visitor lets you define a new operation without changing the classes of the elements on which it operates.

**When to use:**
- You have a stable class hierarchy and want to add many new operations across all of them.
- The operations don't naturally belong on the element classes (e.g., adding a "convert to LaTeX" operation to a syntax tree shouldn't pollute every AST node).

**When NOT to use:**
- The element hierarchy changes often. Visitor optimizes for adding *operations*, at the cost of making *new element types* painful (you must update every visitor).
- You have one operation. Just put it on the elements.
- In a dynamic language, single dispatch + `isinstance` or `functools.singledispatch` often replaces Visitor more clearly.

**Example: AST operations**

```python
from abc import ABC, abstractmethod

# Element hierarchy — stable.
class Node(ABC):
    @abstractmethod
    def accept(self, visitor): ...

class Number(Node):
    def __init__(self, value): self.value = value
    def accept(self, v): return v.visit_number(self)

class Add(Node):
    def __init__(self, left, right): self.left, self.right = left, right
    def accept(self, v): return v.visit_add(self)

class Mul(Node):
    def __init__(self, left, right): self.left, self.right = left, right
    def accept(self, v): return v.visit_mul(self)

# Visitors — add operations without touching Node classes.
class Evaluator:
    def visit_number(self, n): return n.value
    def visit_add(self, n): return n.left.accept(self) + n.right.accept(self)
    def visit_mul(self, n): return n.left.accept(self) * n.right.accept(self)

class Printer:
    def visit_number(self, n): return str(n.value)
    def visit_add(self, n): return f"({n.left.accept(self)} + {n.right.accept(self)})"
    def visit_mul(self, n): return f"({n.left.accept(self)} * {n.right.accept(self)})"

tree = Add(Number(1), Mul(Number(2), Number(3)))
print(tree.accept(Evaluator()))   # 7
print(tree.accept(Printer()))     # (1 + (2 * 3))
```

**Pythonic alternative: `functools.singledispatch`**

```python
from functools import singledispatch

@singledispatch
def evaluate(node): raise NotImplementedError

@evaluate.register
def _(node: Number): return node.value

@evaluate.register
def _(node: Add): return evaluate(node.left) + evaluate(node.right)

@evaluate.register
def _(node: Mul): return evaluate(node.left) * evaluate(node.right)
```

No `accept` methods needed; element hierarchy is genuinely decoupled.

**Pitfalls:**
- **Adding element types breaks visitors.** Every visitor must add a new `visit_X` method. If element types change often, Visitor is the wrong choice.
- **Double dispatch in dynamic languages.** The `accept`/`visit` ceremony exists because static OO has only single dispatch. Pythonic alternatives (singledispatch, isinstance dispatch, pattern matching) are usually clearer.

---

## Choosing among behavioral patterns

| Question | Pattern |
|---|---|
| "How do I notify many objects of a change?" | Observer |
| "How do I swap algorithms at runtime?" | Strategy |
| "How do I encapsulate a request as an object?" | Command |
| "How do I pass a request through a sequence of handlers?" | Chain of Responsibility |
| "How do I share algorithm structure but vary steps?" | Template Method |
| "How do I traverse a collection without exposing it?" | Iterator |
| "How do I change behavior based on internal state?" | State |
| "How do I coordinate complex interactions among many objects?" | Mediator |
| "How do I snapshot and restore object state?" | Memento |
| "How do I add operations to a hierarchy without modifying it?" | Visitor |
