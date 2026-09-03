# Architectural / System-level Patterns

These patterns operate at a higher level than the GoF object patterns. They organize entire applications or services rather than individual classes.

---

## Dependency Injection (DI)

**Intent:** A class receives its dependencies from the outside instead of constructing them itself, making the class testable, configurable, and loosely coupled.

**The core shift:**

```python
# Without DI — class hardcodes its dependency.
class OrderService:
    def __init__(self):
        self.db = PostgresDatabase("prod-host")  # impossible to test in isolation

# With DI — dependency injected.
class OrderService:
    def __init__(self, db: Database):
        self.db = db

# Production:
service = OrderService(PostgresDatabase("prod-host"))
# Test:
service = OrderService(InMemoryDatabase())
```

**Three forms of DI:**

| Form | Mechanism | When |
|---|---|---|
| **Constructor injection** | Pass via `__init__` | Default. Makes dependencies explicit and required. |
| **Setter injection** | Pass via setter method | Optional/replaceable deps. Risk of half-constructed object. |
| **Method injection** | Pass per-call | Per-call variation; rarely a true dependency. |

**Prefer constructor injection** unless you have a specific reason otherwise.

**When to use:**
- Any non-trivial application. DI is the default for testable, modular code.
- Especially when you have I/O dependencies (databases, HTTP clients, file systems, clocks).

**When NOT to use:**
- Tiny scripts or pure functions with no dependencies to inject.
- Don't introduce a heavyweight DI *framework* (Spring, Guice, dependency-injector) until manual wiring becomes painful. Most apps never reach that point.

**Manual wiring (the simplest "container")**

```python
def build_app():
    db = PostgresDatabase(env("DB_HOST"))
    cache = RedisCache(env("REDIS_HOST"))
    user_repo = UserRepository(db)
    order_repo = OrderRepository(db)
    notifier = EmailNotifier(env("SMTP_HOST"))
    return OrderService(order_repo, user_repo, notifier, cache)
```

This "composition root" is one of the few places in your app that knows about concrete implementations. Everything else takes its dependencies as parameters.

**Pitfalls:**
- **Service locator anti-pattern.** Letting classes pull dependencies from a global registry looks like DI but hides coupling. Always pass dependencies in.
- **Over-injection.** A class taking 10+ dependencies signals it does too much. Split it.
- **Framework lock-in.** DI frameworks introduce magic (annotations, scanners). Magic is fine until you debug it. Start with manual wiring.

---

## Repository Pattern

**Intent:** Mediate between the domain and data mapping layers using a collection-like interface for accessing domain objects.

**When to use:**
- You want to abstract over persistence — domain code shouldn't know whether data comes from Postgres, MongoDB, an HTTP API, or a test fixture.
- You're applying Domain-Driven Design and want aggregate roots accessed through Repositories.
- You need to swap data sources for tests.

**When NOT to use:**
- A thin CRUD app with no domain logic. Adding a Repository over the ORM is often pure ceremony.
- The ORM (Django ORM, ActiveRecord) already provides a sufficient abstraction. Don't double-wrap.

**Example: User repository**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class User:
    id: int | None
    email: str
    name: str

# Abstract repo — defines the contract.
class UserRepository(ABC):
    @abstractmethod
    def get(self, user_id: int) -> User | None: ...
    @abstractmethod
    def find_by_email(self, email: str) -> User | None: ...
    @abstractmethod
    def save(self, user: User) -> User: ...
    @abstractmethod
    def delete(self, user_id: int) -> None: ...

# Concrete: SQL implementation — bodies elided; each is a single query.
class SQLUserRepository(UserRepository):
    def __init__(self, connection):
        self._conn = connection
    def get(self, user_id): ...            # SELECT ... WHERE id = %s
    def find_by_email(self, email): ...    # SELECT ... WHERE email = %s
    def save(self, user): ...              # INSERT if user.id is None, else UPDATE
    def delete(self, user_id): ...         # DELETE WHERE id = %s

# Concrete: in-memory for tests.
class InMemoryUserRepository(UserRepository):
    def __init__(self):
        self._users: dict[int, User] = {}
        self._next_id = 1

    def get(self, user_id):
        return self._users.get(user_id)

    def find_by_email(self, email):
        return next((u for u in self._users.values() if u.email == email), None)

    def save(self, user):
        if user.id is None:
            user.id = self._next_id
            self._next_id += 1
        self._users[user.id] = user
        return user

    def delete(self, user_id):
        self._users.pop(user_id, None)
```

Domain services take a `UserRepository`, not knowing or caring which implementation:

```python
class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo

    def register(self, email: str, name: str) -> User:
        if self.repo.find_by_email(email):
            raise ValueError("Email taken")
        return self.repo.save(User(id=None, email=email, name=name))
```

**Pitfalls:**
- **Leaking persistence concerns.** A method like `find_by_email_and_status_and_created_after(...)` is the ORM bleeding through. Either accept this (and consider whether you need a Repository at all) or use a query object.
- **N+1 queries.** Repository methods returning entities one at a time invite N+1. Provide batch methods (`get_many(ids)`) when needed.
- **Generic repositories.** A `Repository<T>` with `find_all` / `find_by_id` / `save` for every entity quickly becomes a leaky wrapper. Prefer specific methods that express domain queries.

---

## MVC / MVP / MVVM

These are all variants of separating **presentation** from **data** from **control logic** so each can be tested and changed independently.

### MVC (Model–View–Controller)

- **Model** — domain data and business rules. Doesn't know about the UI.
- **View** — renders the Model. Doesn't decide what happens on user input.
- **Controller** — receives user input, updates the Model, picks the View.

Used heavily in server-rendered web frameworks (Django, Rails, Spring MVC).

```python
# Model
class Article:
    def __init__(self, id, title, body):
        self.id, self.title, self.body = id, title, body

# View (just renders)
def render_article_page(article: Article) -> str:
    return f"<h1>{article.title}</h1><p>{article.body}</p>"

# Controller (handles request → updates model → picks view)
def article_handler(request, repo: ArticleRepository):
    article = repo.get(request.params["id"])
    if not article:
        return Response(404, "Not found")
    return Response(200, render_article_page(article))
```

### MVP (Model–View–Presenter)

- Like MVC, but the **View** is "humble" — it only displays what the Presenter tells it to. The Presenter holds presentation logic.
- View talks to Presenter via an interface; Presenter is testable without a UI framework.

### MVVM (Model–View–ViewModel)

- The **ViewModel** exposes data and commands as bindable properties.
- The **View** binds to ViewModel properties (declarative data binding does the wiring).
- Used in WPF, SwiftUI, modern JS frameworks (the "VM" lives in component state).

**Picking among MVC/MVP/MVVM:**

| Framework style | Pattern |
|---|---|
| Server-rendered (Django, Rails) | MVC |
| Imperative GUI with manual wiring (older WinForms, GWT) | MVP |
| Declarative reactive UI (SwiftUI, WPF, modern React/Vue) | MVVM |

**Pitfalls (all three):**
- **Fat controllers / presenters / viewmodels.** Business logic creeps out of the Model. Push it back.
- **Anaemic models.** Models with only getters/setters and no behavior leave logic scattered. A rich domain model is often better.
- **Cargo-culting.** Many "MVC" codebases are actually MVA (Model–View–Anything). Pick the variant that fits your framework's idioms.

---

## CQRS — Command Query Responsibility Segregation

**Intent:** Use separate models for read operations (queries) and write operations (commands). The write side enforces invariants; the read side is optimized for projection and presentation.

**When to use:**
- Reads and writes have very different shapes, scaling needs, or consistency requirements.
- A complex domain model is harder to query directly than to update.
- You want denormalized read models (search indexes, reporting tables) maintained alongside a normalized write model.

**When NOT to use:**
- A simple CRUD app. CQRS adds substantial complexity. The split must pay for itself.
- "Eventually consistent" reads aren't acceptable to your domain.

**Shape:**

```
User → Command → Command Handler → Write Model (Aggregate) → Event
                                                                ↓
User ← Query  ← Query Handler  ← Read Model (Projection) ← Event
```

**Minimal example:**

```python
# Write side — focused on invariants and business rules.
class TransferMoneyCommand:
    def __init__(self, from_account, to_account, amount):
        self.from_account = from_account
        self.to_account = to_account
        self.amount = amount

class TransferMoneyHandler:
    def __init__(self, write_repo, event_bus):
        self.repo = write_repo
        self.events = event_bus

    def handle(self, cmd: TransferMoneyCommand):
        src = self.repo.get(cmd.from_account)
        dst = self.repo.get(cmd.to_account)
        src.withdraw(cmd.amount)   # raises if insufficient funds
        dst.deposit(cmd.amount)
        self.repo.save(src)
        self.repo.save(dst)
        self.events.publish(MoneyTransferred(cmd.from_account, cmd.to_account, cmd.amount))

# Read side — denormalized for fast queries, possibly eventually consistent.
class AccountBalanceQuery:
    def __init__(self, account_id):
        self.account_id = account_id

class AccountBalanceQueryHandler:
    def __init__(self, read_db):
        self.db = read_db  # may be a separate DB, cache, or projection

    def handle(self, q: AccountBalanceQuery) -> float:
        return self.db.fetch_balance(q.account_id)
```

**Pitfalls:**
- **Premature CQRS.** A read/write split before you need it doubles your model maintenance. Start unified; split when symptoms appear.
- **Sync drift.** Read models may lag the write model. UI must handle "I just made a change but the list still shows the old value."
- **Two systems of record.** If write and read DBs diverge in bugs, you can't tell which is "true." Treat the write side as authoritative; rebuild reads from it.

---

## Event Sourcing

**Intent:** Persist the state of the system as a sequence of events. The current state is derived by replaying events. Nothing is updated in place.

**When to use:**
- You need a complete audit log of every change (regulated industries, accounting).
- You need to reconstruct past states ("what did the system look like on Tuesday at 3 PM?").
- You want temporal queries or to add new read models retroactively by replaying history.

**When NOT to use:**
- A CRUD app. Event Sourcing replaces the entire persistence model.
- The team isn't ready for the operational complexity (snapshots, schema evolution of old events, replay infrastructure).

**Sketch:**

```python
# Events — past tense, immutable facts.
@dataclass(frozen=True)
class AccountOpened:
    account_id: str
    owner: str

@dataclass(frozen=True)
class MoneyDeposited:
    account_id: str
    amount: float

@dataclass(frozen=True)
class MoneyWithdrawn:
    account_id: str
    amount: float

# Aggregate — rebuilt by folding events.
class Account:
    def __init__(self, account_id):
        self.id = account_id
        self.owner = None
        self.balance = 0.0
        self._uncommitted: list = []

    @classmethod
    def from_history(cls, events):
        if not events:
            return None
        acc = cls(events[0].account_id)
        for e in events:
            acc._apply(e)
        return acc

    def _apply(self, event):
        if isinstance(event, AccountOpened):
            self.owner = event.owner
        elif isinstance(event, MoneyDeposited):
            self.balance += event.amount
        elif isinstance(event, MoneyWithdrawn):
            self.balance -= event.amount

    # Commands produce new events.
    def deposit(self, amount):
        e = MoneyDeposited(self.id, amount)
        self._apply(e)
        self._uncommitted.append(e)

    def withdraw(self, amount):
        if amount > self.balance:
            raise ValueError("Insufficient funds")
        e = MoneyWithdrawn(self.id, amount)
        self._apply(e)
        self._uncommitted.append(e)

# Repository persists events, rebuilds aggregates from them.
class EventStore:
    def load(self, agg_id: str) -> list: ...
    def append(self, agg_id: str, events: list): ...
```

**Pitfalls:**
- **Event schema evolution.** Once written, an event lives forever. Add fields with care (use optional fields, versioned event types).
- **Snapshots.** Replaying thousands of events to rebuild an aggregate is slow. Periodically snapshot the aggregate state to bound replay length.
- **Concurrency.** Two commands modifying the same aggregate must serialize. Use optimistic concurrency on event version numbers.
- **Combined with CQRS.** Event Sourcing is often paired with CQRS — writes append events, reads consume projections built from events. Either pattern alone is already complex; combining them multiplies the burden.

---

## Event-Driven Architecture (EDA)

**Intent:** Services communicate by emitting and reacting to events rather than calling each other directly. Producers don't know who consumes; consumers don't know who produced.

**When to use:**
- You're building multiple services that need to react to the same business event.
- Latency-tolerant integration (you don't need a synchronous reply).
- You want to evolve consumers independently of producers.
- Real-time pipelines (analytics, fraud detection, notifications).

**When NOT to use:**
- Strong-consistency, request/response interactions. Use a synchronous API.
- Workflows where the producer needs to know the outcome before continuing.

**Variants:**

- **Event Notification** — "something happened" with minimal data. Consumers query for details.
- **Event-Carried State Transfer** — events include enough data to act on without callbacks.
- **Event Sourcing** (above) — events are the source of truth, not just notifications.

**Typical infrastructure:** Kafka, RabbitMQ, AWS SNS/SQS, Google Pub/Sub.

**Sketch:**

```python
# Producer (order service)
order_bus.publish("orders.placed", {
    "order_id": order.id,
    "customer_id": order.customer_id,
    "total_cents": order.total_cents,
    "placed_at": order.placed_at.isoformat(),
})

# Consumer A (inventory service)
@subscribe("orders.placed")
def reserve_inventory(event):
    for item in lookup_items(event["order_id"]):
        inventory.reserve(item.sku, item.qty)

# Consumer B (email service)
@subscribe("orders.placed")
def send_confirmation(event):
    customer = users.get(event["customer_id"])
    email.send(customer.email, template="order_confirmed", data=event)

# Consumer C (analytics service)
@subscribe("orders.placed")
def record_metric(event):
    analytics.track("order_placed", event)
```

Each consumer evolves independently; new consumers can be added without changing producers.

**Pitfalls:**
- **Eventual consistency.** Cross-service state takes time to converge. UIs and clients must handle that.
- **At-least-once delivery.** Most brokers deliver each event one-or-more times. Consumers must be **idempotent** (processing the same event twice has the same effect as once).
- **Ordering.** Per-key ordering is often achievable; global ordering rarely is. Design with that in mind.
- **Schema management.** Producers and consumers evolve at different rates. Use a schema registry; version event types.
- **Debuggability.** Distributed traces and correlation IDs are non-negotiable. Without them, "why didn't this work?" becomes hours of log spelunking.
- **Choreography vs orchestration.** EDA is choreography — no one is in charge. For complex multi-step workflows, an orchestrator (saga manager, workflow engine like Temporal) is often clearer.

---

**Combining patterns:** These compose naturally — a service might use DI to wire a Repository that hides Event Sourcing under a CQRS read/write split, consuming and producing events on an Event-Driven bus. Each layer must pay for itself; add only what the problem demands.
