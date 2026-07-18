# design-patterns — a Claude Code skill

A skill that teaches Claude Code to apply software design patterns *judiciously* — picking the right pattern for a real problem, recognizing when no pattern is needed, and resisting over-engineering.

Covers all 23 Gang of Four patterns plus the architectural patterns and design principles from the [GeeksforGeeks design patterns curriculum](https://www.geeksforgeeks.org/system-design/software-design-patterns/):

- **Creational** (7): Singleton, Factory Method, Abstract Factory, Builder, Prototype, Object Pool, Lazy Initialization
- **Structural** (7): Adapter, Decorator, Facade, Composite, Proxy, Bridge, Flyweight
- **Behavioral** (10): Observer, Strategy, Command, Chain of Responsibility, Template Method, Iterator, State, Mediator, Memento, Visitor
- **Architectural** (6): Dependency Injection, Repository, MVC/MVP/MVVM, CQRS, Event Sourcing, Event-Driven Architecture
- **Principles** (5+): SOLID, DRY, KISS, YAGNI, Composition over Inheritance

## What makes this skill different

Most pattern catalogues are reference material — they show you the structure of each pattern. This skill is **decision-making material** — it helps Claude pick the *right* pattern (or no pattern) by:

1. **Leading with the problem.** Every pattern entry starts with the concrete pain point it solves.
2. **Telling Claude when *not* to use a pattern.** Each entry has an explicit "When NOT to use" section.
3. **Calling out language-idiomatic alternatives.** Many GoF patterns are workarounds for 1990s Java; modern Python, JS, and TS often have built-in equivalents (generators for Iterator, functions for Strategy, modules for Singleton, etc.).
4. **Naming anti-patterns up front.** The main `SKILL.md` opens with the failure modes (Singleton-everywhere, Factory for `new User()`, pattern stacking, premature abstraction).
5. **Treating principles as tensions.** SOLID, DRY, KISS, and YAGNI all *oppose* each other in their over-applied forms. The principles guide explains the trade-offs explicitly.

## Installation

### Global (available in every project)

```bash
# macOS / Linux / WSL
mkdir -p ~/.claude/skills
cp -r design-patterns ~/.claude/skills/

# Windows (PowerShell)
mkdir $env:USERPROFILE\.claude\skills -Force
Copy-Item -Recurse design-patterns $env:USERPROFILE\.claude\skills\
```

### Project-scoped (committed with your repo, shared with teammates)

```bash
mkdir -p .claude/skills
cp -r design-patterns .claude/skills/
git add .claude/skills/design-patterns
```

Start a new Claude Code session and the skill loads automatically. Verify with `/skills` or by asking Claude "what skills are available?".

## How it's structured (progressive disclosure)

Claude only loads what it needs:

```
design-patterns/
├── SKILL.md                    # Always loaded — decision guide & pattern selector
└── references/
    ├── creational.md           # Loaded only when a creational pattern is relevant
    ├── structural.md           # Loaded only when a structural pattern is relevant
    ├── behavioral.md           # Loaded only when a behavioral pattern is relevant
    ├── architectural.md        # Loaded only when an architectural pattern is relevant
    └── principles.md           # Loaded only when reviewing for code quality
```

The main `SKILL.md` (~250 lines) acts as a router: it has selection tables that map problems to patterns and tells Claude which reference file to read. Each reference file is loaded on demand, keeping context usage low.

## When the skill activates

The skill's frontmatter description triggers it for requests like:

- "Refactor this so I can swap database backends"
- "Apply the Strategy pattern to this payment code"
- "Review this for SOLID violations"
- "Design a notification system that supports email, SMS, and push"
- "Why is this code hard to test?"
- "Should I use a Singleton here?"
- "Decouple this UI from the data fetching"

It explicitly *won't* push patterns where they don't belong — it'll often suggest a simpler solution (a function, a dataclass, a module-level value) instead.

## Customizing

Edit `SKILL.md` to:
- Add your team's preferred language for examples (currently Python; TypeScript and Java appear where the static-type idiom matters).
- Add company-specific patterns (e.g., your standard repository base class, your event bus conventions).
- Add anti-patterns observed in your codebase to the warnings section.

Reference files can be edited or extended without changing `SKILL.md`. Add new reference files for company-specific patterns and link them from `SKILL.md`'s reference index.

## License

Use freely. No warranty.
