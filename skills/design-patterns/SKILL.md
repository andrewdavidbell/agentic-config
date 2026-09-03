---
name: design-patterns
description: "Guide software design pattern selection and implementation. Fire on queries like 'should I use X pattern?', 'what pattern fits this?', 'refactor to use Y', 'review this for SOLID/DRY', or 'how do I decouple/design this cleanly?'. Do NOT use for routine bug fixes, syntax refactors, or tool/library questions."
---

# Software Design Patterns

This skill helps select, apply, and explain design patterns correctly — and equally importantly, helps avoid applying them when they aren't needed.

## Core principle: patterns are answers, not goals

A design pattern is the answer to a specific recurring problem. If the problem isn't present, the pattern is overhead. Before applying any pattern, you must be able to name the concrete problem it solves in **this** codebase. "It might be useful later" is not a problem; it's [YAGNI](references/principles.md#yagni--you-arent-gonna-need-it).

## Workflow

When asked to design, refactor, or review code:

1. **Understand the problem first.** Read the existing code (if any). Identify the *actual* pain point: rigid coupling, duplicated logic, hard-to-extend behavior, complex object construction, scattered state mutations, etc. Don't reach for a pattern until you can articulate the problem in one sentence.

2. **Check whether a simpler solution exists.** Most problems are solved by a function, a class, or composition — not a named pattern. Apply [KISS](references/principles.md#kiss--keep-it-simple-stupid) before reaching for patterns.

3. **Match problem to pattern** using the selection guide below. If two patterns could apply, pick the one with less indirection.

4. **Read the relevant reference file** (e.g., `references/creational.md`, relative to this skill's directory) with the Read tool before implementing. Do not implement from memory — reference files contain the exact structure, common pitfalls, and when-not-to-use guidance. If the task spans categories (e.g., a Factory that returns Strategies), read each relevant file.

5. **Implement idiomatically for the target language.** A Python Singleton looks nothing like a Java Singleton. Reference files include language-specific examples where the difference matters.

6. **Validate by removing the pattern.** Ask: "If I deleted this abstraction, what would break?" If the answer is "nothing meaningful," remove it.

## Pattern selection guide

Identify your problem in the left column, then load the referenced file for full guidance.

### Object creation problems → [references/creational.md](references/creational.md)

| Problem | Pattern |
|---|---|
| Exactly one instance must exist (logger, config, connection pool) | **Singleton** — but prefer module-level state or DI |
| Need to create one of several related objects based on input | **Factory Method** |
| Need to create families of related objects (UI toolkit for multiple OSes) | **Abstract Factory** |
| Object has many optional construction parameters; constructor is unwieldy | **Builder** |
| Creating new objects is expensive; cloning existing ones is cheaper | **Prototype** |
| Object creation/destruction is expensive (DB connections, threads) | **Object Pool** |
| Expensive resource should only be initialized when first accessed | **Lazy Initialization** |

### Class/object composition problems → [references/structural.md](references/structural.md)

| Problem | Pattern |
|---|---|
| Two incompatible interfaces need to work together | **Adapter** |
| Need to add behavior to objects without subclassing | **Decorator** |
| Complex subsystem needs a simple unified interface | **Facade** |
| Tree of objects where leaves and composites are treated uniformly | **Composite** |
| Need a stand-in for another object (lazy load, access control, remote, caching) | **Proxy** |
| Abstraction and implementation should vary independently | **Bridge** |
| Need to support huge numbers of similar objects efficiently (memory) | **Flyweight** |

### Object interaction / behavior problems → [references/behavioral.md](references/behavioral.md)

| Problem | Pattern |
|---|---|
| Multiple objects need to react to state changes in another object | **Observer** |
| Need to swap algorithms at runtime (sort order, payment method, compression) | **Strategy** |
| Need to encapsulate a request as an object (undo/redo, queues, logging) | **Command** |
| Request should be handled by one of several handlers; sender doesn't know which | **Chain of Responsibility** |
| Algorithm skeleton is fixed but specific steps vary by subclass | **Template Method** |
| Need uniform traversal over a collection without exposing internals | **Iterator** |
| Object behavior changes based on internal state (state machines) | **State** |
| Many objects communicate in complex ways; want to centralize coordination | **Mediator** |
| Need to capture and restore an object's state (snapshots, undo) | **Memento** |
| Need to add operations to a class hierarchy without modifying the classes | **Visitor** |

### System / architectural problems → [references/architectural.md](references/architectural.md)

| Problem | Pattern |
|---|---|
| Dependencies are hardcoded; tests are hard; coupling is tight | **Dependency Injection** |
| Data access is scattered; want a clean abstraction over persistence | **Repository** |
| Separating UI, data, and control logic in an app | **MVC / MVP / MVVM** |
| Reads and writes have very different scaling/modeling needs | **CQRS** |
| Need an audit log of every change; need to reconstruct past states | **Event Sourcing** |
| Loosely coupled services that react to changes asynchronously | **Event-Driven Architecture** |

### Code quality issues → [references/principles.md](references/principles.md)

| Smell | Apply |
|---|---|
| Classes do too much; changes ripple unpredictably | **SOLID** (especially SRP, OCP) |
| The same logic appears in multiple places | **DRY** — but don't over-abstract; tolerate some duplication |
| Code is unnecessarily clever or layered | **KISS** — flatten it |
| Speculative generality, hooks "for the future" | **YAGNI** — delete it |
| Deep inheritance hierarchies, fragile base classes | **Composition over Inheritance** |

## Anti-patterns to avoid

These mistakes appear when patterns are applied without need:

- **Premature abstraction.** Introducing an interface for one implementation "in case we add another" is YAGNI. Add the interface when the second implementation appears.
- **Pattern stacking.** Wrapping a Decorator around a Proxy around an Adapter to a Facade — each layer must justify itself. If you can't explain why a layer exists, remove it.
- **Patterns instead of language features.** Don't write Java-style Iterators in Python (use generators). Don't write Strategy in a language with first-class functions (just pass the function). Don't write Singleton in a module-based language (use a module).
- **Inheritance for code reuse.** This is the most common cause of fragile designs. Reach for composition first; reach for inheritance only when there's a true *is-a* relationship and the subclass honors the [Liskov Substitution Principle](references/principles.md#l--liskov-substitution-principle-lsp).

## Language-specific shortcuts

Many GoF patterns were workarounds for limitations in 1990s C++/Java. Modern languages often have built-in equivalents:

| Pattern | Python idiom | TypeScript/JS idiom |
|---|---|---|
| Singleton | Module-level state | Module-level `const` |
| Strategy | First-class function | First-class function / arrow fn |
| Iterator | Generator (`yield`) | `Symbol.iterator` / generator |
| Decorator (GoF) | `@decorator` syntax (subset of cases) | Higher-order function |
| Observer | `asyncio` events, `__set_name__` descriptors | `EventTarget`, RxJS |
| Command | Closure | Closure |
| Template Method | Subclass with hook methods | Subclass / higher-order function |
| Factory | `@classmethod` constructor | Static method / factory function |

Before implementing a pattern textbook-style, check if the language has an idiomatic shortcut.

## Reviewing code for pattern opportunities

When asked to review existing code for design improvements:

1. **Look for symptoms, not patterns.** Symptoms include: long `if/elif` chains on a type field, duplicated branching across methods, classes with `do_everything()` methods, deeply nested conditionals, hardcoded dependencies preventing testing, change-one-place-break-another fragility.
2. **Name the symptom.** "This method has a 7-branch type check — that's a Strategy/State opportunity."
3. **Show the smallest possible refactor.** Don't rewrite the world. Extract the one piece that benefits, leave the rest.
4. **Quantify the win.** "This change removes 40 lines of duplication and lets us add new payment types without modifying existing code." If you can't articulate the win, don't make the change.

## Explaining patterns to users

When teaching a pattern:

1. State the problem it solves first.
2. Show the painful code *without* the pattern.
3. Show the same code *with* the pattern.
4. Explicitly call out the trade-off — every pattern adds indirection in exchange for some flexibility, decoupling, or expressiveness. The user should see what they're paying.
5. Note when *not* to use it.

## Reference index

- [references/creational.md](references/creational.md) — Singleton, Factory Method, Abstract Factory, Builder, Prototype, Object Pool, Lazy Initialization
- [references/structural.md](references/structural.md) — Adapter, Decorator, Facade, Composite, Proxy, Bridge, Flyweight
- [references/behavioral.md](references/behavioral.md) — Observer, Strategy, Command, Chain of Responsibility, Template Method, Iterator, State, Mediator, Memento, Visitor
- [references/architectural.md](references/architectural.md) — Dependency Injection, Repository, MVC/MVP/MVVM, CQRS, Event Sourcing, Event-Driven Architecture
- [references/principles.md](references/principles.md) — SOLID, DRY, KISS, YAGNI, Composition vs Inheritance
