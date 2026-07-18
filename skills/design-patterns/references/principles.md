# Design Principles

Principles are the values that *guide* pattern selection. Patterns are concrete; principles are tensions you balance. Every principle below can be over-applied.

---

## SOLID

Five object-oriented design principles. Each addresses a specific failure mode in OO code.

### S — Single Responsibility Principle (SRP)

**A class should have one, and only one, reason to change.**

The "reason to change" framing matters. SRP isn't "do one thing"; it's "answer to one stakeholder / one axis of change."

**Symptom of violation:**
```python
class Report:
    def fetch_data(self): ...        # changes when DB schema changes
    def calculate_totals(self): ...  # changes when business rules change
    def render_pdf(self): ...        # changes when PDF library changes
    def email_to(self, addr): ...    # changes when email provider changes
```
Four reasons to change, four ways to break unrelated features. Split into `ReportData`, `TotalsCalculator`, `PDFRenderer`, `EmailSender`.

**Don't over-apply:** SRP doesn't mean every class has one method. A `User` class with `name`, `email`, `password_hash`, `verify_password()`, and `to_dict()` is fine — those all change together.

### O — Open/Closed Principle (OCP)

**Software entities should be open for extension, but closed for modification.**

You should be able to add new behavior without editing existing code. Achieved through polymorphism: new subclass, new Strategy, new handler in a Chain.

**Symptom of violation:**
```python
def calculate_discount(order, customer_type):
    if customer_type == "regular":   return order.total * 0.05
    elif customer_type == "vip":     return order.total * 0.15
    elif customer_type == "partner": return order.total * 0.20
    # Adding "wholesale" means editing this function.
```

**OCP-aligned version:**
```python
class DiscountPolicy(ABC):
    @abstractmethod
    def apply(self, order) -> float: ...

class RegularDiscount(DiscountPolicy):
    def apply(self, order): return order.total * 0.05
# Adding a new policy is a new class; existing code is untouched.
```

**Don't over-apply:** OCP is aspirational. You can't predict all future axes of change; trying to make every dimension polymorphic is YAGNI. Make a thing closed when you've actually been bitten by changes along that axis, not before.

### L — Liskov Substitution Principle (LSP)

**Subtypes must be substitutable for their base types.** If `B` is a subclass of `A`, code that works with `A` must work with `B` without surprises.

**Classic violation: Square is-a Rectangle?**
```python
class Rectangle:
    def set_width(self, w): self.width = w
    def set_height(self, h): self.height = h

class Square(Rectangle):
    def set_width(self, w):  self.width = self.height = w   # surprise: changes height
    def set_height(self, h): self.width = self.height = h   # surprise: changes width

# Code that worked for Rectangle now breaks:
def stretch(rect: Rectangle):
    rect.set_width(rect.width * 2)
    assert rect.height == original_height   # fails for Square
```

In the mathematical sense a square *is* a rectangle. In a *mutable* OO model with independent width/height setters, it isn't. LSP forces honesty about behavior, not just structure.

**Common LSP violations:**
- Subclass throws exceptions the parent doesn't.
- Subclass strengthens preconditions (rejects inputs the parent accepts).
- Subclass weakens postconditions (returns less than the parent promises).
- Subclass changes invariants (parent says "thread-safe," subclass isn't).

**Fix:** Use composition, or split the hierarchy. Squares and Rectangles can both implement a `Shape` interface with `area()` and nothing else.

### I — Interface Segregation Principle (ISP)

**Clients should not be forced to depend on methods they do not use.**

Many small, focused interfaces beat one large omnibus interface.

**Symptom of violation:**
```python
class Worker(ABC):
    @abstractmethod
    def work(self): ...
    @abstractmethod
    def eat(self): ...
    @abstractmethod
    def sleep(self): ...

class Robot(Worker):
    def work(self): ...
    def eat(self): raise NotImplementedError   # robots don't eat
    def sleep(self): raise NotImplementedError # robots don't sleep
```

Split interfaces by capability:
```python
class Workable(ABC):
    @abstractmethod
    def work(self): ...

class Feedable(ABC):
    @abstractmethod
    def eat(self): ...

class Sleepable(ABC):
    @abstractmethod
    def sleep(self): ...

class Human(Workable, Feedable, Sleepable): ...
class Robot(Workable): ...
```

**Don't over-apply:** Splitting `read` and `write` on `File` into two interfaces just because some clients only read might be over-engineering for your scale.

### D — Dependency Inversion Principle (DIP)

**High-level modules should not depend on low-level modules. Both should depend on abstractions. Abstractions should not depend on details; details should depend on abstractions.**

In practice: your business logic shouldn't import a specific database client; it should depend on an interface that the database client implements.

```python
# Violates DIP — high-level OrderService depends on low-level Postgres.
class OrderService:
    def __init__(self):
        self.db = PostgresConnection(...)
    def place(self, order):
        self.db.execute("INSERT INTO orders ...")

# Honors DIP — both depend on the OrderRepository abstraction.
class OrderRepository(ABC):
    @abstractmethod
    def save(self, order): ...

class PostgresOrderRepository(OrderRepository):
    def __init__(self, conn): self.conn = conn
    def save(self, order): self.conn.execute(...)

class OrderService:
    def __init__(self, repo: OrderRepository):
        self.repo = repo
    def place(self, order):
        self.repo.save(order)
```

DIP is the conceptual foundation of **Dependency Injection** as a technique.

---

## DRY — Don't Repeat Yourself

**Every piece of knowledge must have a single, unambiguous, authoritative representation within a system.**

DRY is about **knowledge**, not character sequences. Two functions that look identical but represent different concepts that just *happen* to have the same implementation are not DRY violations — they will evolve apart, and forcing them to share is wrong.

**Real DRY violation:**
```python
# Two places encode the same business rule.
# In invoice service:
discount = order.total * 0.10 if order.total > 1000 else 0
# In email service:
threshold_message = f"Spend over $1000 for 10% off!"
```
Changing the threshold or percentage means editing both. Extract the rule.

**False DRY violation:**
```python
def is_admin(user): return user.role == "admin"
def is_archived(post): return post.status == "archived"
```
Both check a string equality, but they represent different domain concepts. Merging them ("compare attribute to value") creates a generic function that obscures intent.

**Over-applied DRY symptoms:**
- A "BaseEntity" class with seven optional behaviors no one fully uses.
- A generic "process" function with 12 parameters.
- Abstractions invented to eliminate two-line duplication, creating dependencies between unrelated modules.

**Rule of thumb:** tolerate duplication until you have **3 occurrences** of the same logic that *change together*. Premature DRY creates the wrong abstraction; the wrong abstraction is more expensive than duplication.

---

## KISS — Keep It Simple, Stupid

**Simplicity should be a key goal in design, and unnecessary complexity should be avoided.**

The simplest design that solves the problem wins. Cleverness is a debt.

**KISS asks:**
- Is there a one-liner that does this?
- Does this need a class, or would a function do?
- Does this need an abstraction, or would a literal do?
- Could a junior dev read this in 30 seconds?

**Anti-KISS smells:**
- Three layers of indirection for a problem with one shape.
- Configuration system for things that never need to be configured.
- Generic framework built for one caller.
- Reflective / metaprogrammed code where a switch statement would do.

**KISS vs other principles:** KISS often opposes DIP, OCP, and DRY in their over-applied forms. When in doubt, lean KISS. You can always add abstraction later when concrete pain emerges; you cannot easily *remove* abstraction once it's spread through a codebase.

---

## YAGNI — You Aren't Gonna Need It

**Always implement things when you actually need them, never when you just foresee that you need them.**

YAGNI rejects speculative features and speculative generality. Most predicted future needs never materialize, or materialize differently than expected.

**YAGNI violations:**
- "We might add Postgres support later" → wrap everything behind a database interface for a system that uses only SQLite.
- "Let's parameterize this" → 14 optional config knobs no one uses.
- "What if we want to do this in parallel?" → async/threaded version of code that runs in 50ms.
- "Let's make it a plugin system" → for the one plugin we have.

**The cost of speculative generality:**
1. Code complexity (more to read, more to test, more to maintain).
2. Calcified design (the speculated structure is rarely what you actually need; tearing it out is expensive).
3. Onboarding friction (new devs ask "why is this here?" and no one knows).

**YAGNI rule of thumb:** if a feature, abstraction, or extension point doesn't have a *current* concrete user, leave it out. Real users will surface real requirements; design for those.

**YAGNI is not "never refactor."** When a real need emerges that the current design doesn't accommodate, refactor — that's healthy. YAGNI prohibits building for needs that haven't emerged.

---

## Composition over Inheritance

**Favor object composition over class inheritance.**

Inheritance creates a permanent, tightly coupled relationship: subclass depends on superclass internals, changes to the parent break the child, and you can only have one parent (in single-inheritance languages). Composition uses has-a relationships; pieces can be swapped, mocked, or replaced independently.

**Inheritance abuse:**
```python
class Animal:
    def eat(self): ...
    def sleep(self): ...

class Bird(Animal):
    def fly(self): ...

class Penguin(Bird):  # uh oh
    def fly(self): raise NotImplementedError("penguins don't fly")
```

The hierarchy lied. Penguin *is-a* Bird but doesn't honor Bird's promise. This is an LSP violation born of inheritance-first thinking.

**Composition version:**
```python
class Animal:
    def __init__(self, locomotion, diet):
        self.locomotion = locomotion
        self.diet = diet

    def move(self): self.locomotion.move(self)
    def eat(self):  self.diet.eat(self)

class Flying:
    def move(self, animal): print(f"{animal} flies")

class Swimming:
    def move(self, animal): print(f"{animal} swims")

class Walking:
    def move(self, animal): print(f"{animal} walks")

eagle = Animal(Flying(), Carnivore())
penguin = Animal(Swimming(), Piscivore())
```

Now "can it fly?" is a property of the locomotion strategy, not a fact about the class hierarchy. New behaviors are new components, not new subclasses.

**When inheritance is right:**
- True is-a relationship that honors LSP — `BinaryTree` is-a `Tree`, `CheckingAccount` is-a `Account`.
- The subclass meaningfully extends behavior without violating the parent's contract.
- Sealed/closed hierarchies where you control all subclasses (algebraic-data-type style — `Shape = Circle | Square | Triangle`).

**When inheritance is wrong:**
- "Code reuse" is the only reason — extract a helper, inject a collaborator.
- The subclass needs to disable, override-with-exception, or fundamentally change parent behavior.
- The hierarchy is more than 2-3 levels deep — almost always a smell.
- Multiple axes of variation (animal type × diet × habitat × locomotion) — composition handles this; inheritance produces combinatorial explosion.

---

## How principles interact

| Tension | Resolution |
|---|---|
| **DRY vs YAGNI** | Don't abstract speculatively. Wait for 3 real occurrences with shared knowledge. |
| **OCP vs KISS** | Make extension points where change has actually occurred, not where it might. |
| **SRP vs cohesion** | "Single responsibility" doesn't mean "single method." Group what changes together. |
| **DIP vs simplicity** | Inject what you'd want to mock in tests. Don't wrap dependencies that never vary. |
| **Composition vs inheritance** | Default to composition; reach for inheritance for true substitutable subtypes. |

**Meta-principle: principles serve the code, not the other way around.** A "principles-violating" design that is clear, fast, and easy to change is a good design. A "principle-pure" design no one can read is a bad one.

---

## Applying principles to a code review

When reviewing code:

1. **Read what the code does** before judging structure. Many "violations" disappear once you understand the domain.
2. **Look for symptoms, not violations.** "This function is 200 lines" is a symptom; "violates SRP" is jargon. Lead with the symptom.
3. **Propose the smallest change that addresses the symptom.** Don't rewrite a module to extract one function.
4. **Acknowledge trade-offs.** "Splitting this class will help testability but add a layer; I think the testability is worth it because X."
5. **Be honest about scale.** A 200-line script doesn't need DIP. An enterprise service handling millions of requests does.

Principles are sharpest when applied to code that is already in pain. Applied prophylactically, they're a tax. Applied in response to real problems, they're medicine.
