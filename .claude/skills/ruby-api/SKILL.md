---
name: ruby-api
description: Ruby and Rails work in the API — controllers, models, migrations, RSpec specs, funnel screens and locales. Use whenever the request touches a .rb or .erb file, a spec, a query, or the French wording shown in the app, even if Rails is never named.
---

# Rails API

## Test first
- Write or update the spec before the implementation; run it and watch it fail
  for the expected reason.
- One file: `bin/rspec spec/path/to/foo_spec.rb:42`
- Full suite: `bin/rspec`

## Queries
- Assume every `has_many` access in a loop is an N+1 until proven otherwise;
  reach for `includes`/`preload` and assert the query count in the spec.
- Scopes belong on the model, not inlined in controllers.

## Conventions
- `bundle exec rubocop` must pass; it is configured, not advisory.
- ERB changes: `bin/erb_lint --lint-all`.
- Screen copy and wording live under `app/funnels/screens/**` and
  `config/locales/screens/*.fr.yml` — that is the source of truth, not a ticket.
