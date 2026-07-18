# Elixir Testing Guidelines (ESpec)

How we write tests in this project. We use [ESpec](https://github.com/antonmi/espec),
a BDD framework for Elixir. These rules adapt the principles from
[Even Better Specs](https://evenbetterspecs.github.io/) to ESpec syntax.

Two ideas underpin everything below:

- **Tests must be self-contained, not DRY.** Optimize for a reader who lands on a
  single `it` block and needs to understand it without scrolling.
- **Tests follow Arrange → Act → Assert.** Set up state, exercise the code, assert
  the outcome — in that order, visibly, inside each example.

---

## Paramount Rules

These three rules are non-negotiable. Everything else is guidance.

### 1. Use `describe` / `context` for context setting

`describe` names the unit under test. `context` names a scenario or a branch of
that unit's behavior. Every example lives inside a `describe`, and every
conditional scenario lives inside a `context`.

- `describe` — the function or unit being tested. Use `"function_name/arity"`.
- `context` — a precondition or scenario. **Always start with `"when"`** (or
  `"with"` / `"without"`).

```elixir
defmodule Accounts.RegisterUserSpec do
  use ESpec

  describe "register_user/1" do
    context "when the email is valid" do
      it "creates the user" do
        # ...
      end
    end

    context "when the email is already taken" do
      it "returns an error tuple" do
        # ...
      end
    end
  end
end
```

Do **not** encode the scenario in the `it` description with an inline conditional
(`it "returns an error if the email is taken"`). Push the condition up into a
`context`.

### 2. One `expect` per `it` clause

Each `it` block asserts exactly one thing. One example, one behavior, one
expectation.

```elixir
# Good — one expectation, one behavior
it "returns an ok tuple" do
  expect(register_user(valid_attrs)) |> to(be_ok_result())
end

it "persists the email" do
  {:ok, user} = register_user(valid_attrs)
  expect(user.email) |> to(eq("edson@pele.com"))
end
```

```elixir
# Bad — multiple expectations in one example
it "registers the user" do
  {:ok, user} = register_user(valid_attrs)
  expect(user.email) |> to(eq("edson@pele.com"))
  expect(user.active) |> to(be_true())
  expect(User.count()) |> to(eq(1))
end
```

If several assertions genuinely share expensive setup, extract that setup into a
private helper function and call it from each example — do not merge the
assertions. Readability and precise failure messages win over saving a few lines.

### 3. `it` clauses never start with "should"

The `it` description completes the sentence "it ...". Write the behavior as a
present-tense statement of fact, not a recommendation.

```elixir
# Good
it "returns the total price"
it "rejects a blank name"
it "raises when the pilot does not exist"

# Bad
it "should return the total price"
it "should reject a blank name"
```

### 4. `it` clauses should not include ticket numbers

```elixir
# Good
it "returns the total price"

# Bad
it "returns the total price (atomic - K7)"
```

---

## Structure & Naming

### File and module layout

- One spec file per module, named `*_spec.exs`, placed under `spec/`.
- The spec module is the tested module name plus `Spec`
  (`Accounts.Billing` → `Accounts.BillingSpec`).
- `use ESpec` at the top. Nothing else at module scope unless it is a helper
  function used by the examples.

```elixir
defmodule Accounts.BillingSpec do
  use ESpec

  describe "charge/2" do
    # ...
  end
end
```

### Describe the thing under test

- Use `"name/arity"` for functions: `describe "authenticate/2"`.
- Group everything for one function under a single `describe`. Nest `context`
  blocks for scenarios.
- Reach for `described_module()` instead of hardcoding the module name, so a
  rename only touches the top of the file.

### Short descriptions

A description must not exceed **100 characters** or span multiple lines. If you
need more words to explain the case, that is a signal to split it into a nested
`context`.

---

## Setup: Prefer Explicit Over Magic

The Even Better Specs philosophy is that indirection in tests costs more than the
duplication it removes. In ESpec terms:

### Avoid `let` / `let!`

Memoized helpers force the reader to hunt for a definition elsewhere and then
mentally apply deltas. Define the data **inside the example** instead.

```elixir
# Avoid
let :user, do: build(:user, first_name: "Edson", last_name: "Pele")

# Prefer
it "greets the user by name" do
  user = build(:user, first_name: "Edson", last_name: "Pele")
  expect(greet(user)) |> to(eq("Hello, Edson"))
end
```

### Avoid `before` hooks

`before` blocks scatter a test's Arrange step away from its body. Set up the state
you need directly in each `it`. If setup is verbose, extract a named helper
function and call it explicitly — the call site stays visible.

```elixir
# Avoid
before do
  {:shared, order: create(:order, total: 100)}
end

# Prefer
it "applies the discount" do
  order = create(:order, total: 100)
  expect(apply_discount(order, 0.1).total) |> to(eq(90))
end
```

### Avoid shared examples

`it_behaves_like` / `use ESpec, shared: true` trades duplication for hidden
complexity. Write the examples out explicitly for each module. Tests are not
production code — repetition is acceptable when it keeps each example readable in
isolation.

### `subject`

`subject` is acceptable for a trivial subject-under-test when it removes noise, but
never let it hide meaningful setup. When in doubt, be explicit in the example.

---

## Data

- **Factories, not fixtures.** Use factories (e.g. ExMachina) — they are more
  flexible and easier to work with.
- **Build over insert.** Prefer `build` / `build_stubbed`-style factories over
  database inserts when the code under test does not touch the database. It keeps
  tests fast.
- **Create only the data you need.** Extra records slow the suite and obscure what
  the test actually depends on. Do not create a record "just in case".

---

## Assertions & Matchers

- **Use `expect ... |> to(...)`**, the pipe syntax, as the default. It reads
  left-to-right as Arrange-Act-Assert.

  ```elixir
  expect(response.status) |> to(eq(200))
  expect(user) |> to_not(be_nil())
  ```

- Prefer `to(...)` / `to_not(...)` over the `should` / `should_not` form for
  consistency with the pipe style above.

- **Pick the most specific matcher.** A precise matcher gives a better failure
  message than a raw boolean.

  ```elixir
  # Prefer
  expect(result) |> to(be_ok_result())
  expect(list) |> to(have_count(3))
  expect(map) |> to(have_key(:id))

  # Over
  expect(match?({:ok, _}, result)) |> to(be_true())
  ```

- **Use `match_pattern` for tuple/struct shapes:**

  ```elixir
  expect(register_user(attrs)) |> to(match_pattern({:ok, %User{}}))
  ```

- **Assert errors with `raise_exception`:**

  ```elixir
  it "raises when the pilot is missing" do
    expect(fn -> find_pilot!(0) end) |> to(raise_exception(Ecto.NoResultsError))
  end
  ```

---

## Mocking & External Dependencies

Mock collaborators that are **not** the responsibility of the code under test;
exercise the real thing when it *is* the responsibility.

- **Use `allow ... |> to(accept ...)`** for stubbing, and `passthrough` for
  partial mocks.

  ```elixir
  describe "github_stars/1" do
    it "renders the star count" do
      allow(Github) |> to(accept(:fetch_stars, fn 1 -> 10 end))
      expect(github_stars(1)) |> to(eq("Stars: 10"))
    end
  end
  ```

- **Stub HTTP calls** — never hit the network in a spec. Use WebMock/VCR-style
  tooling or an injected HTTP client stubbed via `accept`.

- **Verify interactions with `accepted`** when the call itself is the behavior
  under test:

  ```elixir
  it "notifies the mailer" do
    allow(Mailer) |> to(accept(:deliver))
    register_user(valid_attrs)
    expect(Mailer) |> to(accepted(:deliver))
  end
  ```

- **Keep integration tests few.** Testing real dependencies is fine in a small
  number of deliberate cases, but overusing it makes the suite slow and brittle.

---

## Coverage

- **Test valid, edge, and invalid cases.** A test that only covers the happy path
  is not much of a safety net. Model each case as its own `context`:

  ```elixir
  describe "fetch_product/1" do
    context "when the product exists" do
      it "returns the product" do
        # ...
      end
    end

    context "when the product does not exist" do
      it "returns :not_found" do
        # ...
      end
    end

    context "when the user is not authenticated" do
      it "returns :unauthorized" do
        # ...
      end
    end
  end
  ```

- If a single unit needs an unwieldy number of cases, treat that as a smell: the
  module under test is likely doing too much and should be broken up.

---

## Quick Checklist

Before you commit a spec, confirm:

- [ ] Every example sits inside a `describe`; every scenario inside a `"when …"` `context`.
- [ ] Each `it` has exactly one `expect`.
- [ ] No `it` description starts with "should".
- [ ] `it` descriptions only contain descriptions of the behavior under test
- [ ] No description exceeds 100 characters or wraps lines.
- [ ] No `let` / `let!`, no `before`, no shared examples — setup is explicit in the example.
- [ ] Data is built with factories, only what the test needs.
- [ ] Assertions use `expect ... |> to(...)` with the most specific matcher available.
- [ ] External dependencies and HTTP are mocked; the network is never touched.
- [ ] Valid, edge, and invalid cases are all covered.
