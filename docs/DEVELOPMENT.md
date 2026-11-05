# Development

## Setup

The plugin runs inside a Discourse checkout. You need a
[Discourse development environment](https://meta.discourse.org/t/-/336366)
(Ruby 4.0, PostgreSQL 13+, Redis, Node 22+, pnpm).

```bash
cd discourse/plugins
git clone https://github.com/narayanan79/discourse-insightful.git
cd ..
bin/rails db:migrate          # applies plugin migrations and seed fixtures
bin/ember-cli --proxy http://localhost:3000   # or: bin/dev
```

Plugin-local linting uses its own small toolchain:

```bash
cd plugins/discourse-insightful
pnpm install
bundle install
```

## Layout

```
plugin.rb                       settings, routes, serializers, events, patches
controllers/                    InsightfulController
lib/                            services, extensions, model, directory SQL
lib/tasks/                      rake tasks (backfill, recalculate)
app/jobs/scheduled/             CleanupInsightfulDaily
db/migrate, db/post_migrate     schema changes (post_migrate = after deploy)
db/fixtures/                    seed data (post action type 51)
assets/javascripts/discourse/   initializer, component, connectors, routes
assets/stylesheets/             insightful.scss
config/                         settings and locales
spec/, test/javascripts/        RSpec and QUnit
```

Ruby files are loaded with `require_relative` from `plugin.rb`. The plugin has
no Rails engine.

## Conventions

- **Business logic** lives in the `Service::Base` services, written per core's
  `docs/developer-guides/docs/03-code-internals/20-service-objects.md`. Use
  `fail!` to stop a generic step (its return value is ignored). Writes go inside
  `transaction`; side effects go after it.
- **Permissions** go through `Guardian#can_mark_post_insightful?`. Do not
  re-implement the rule anywhere else.
- **Identifiers** go through `DiscourseInsightful::POST_ACTION_TYPE_ID`,
  `USER_ACTION_GIVEN` and `USER_ACTION_RECEIVED`.
  `PostActionType.types[:insightful]` is always `nil`.
- **Frontend state** lives in the tracked post properties only.
- **Migrations:** generate them with `bin/rails g plugin_migration … --plugin-name=discourse-insightful`.
  Destructive changes go in `db/post_migrate`. Never call models from a migration.
- **Strings:** every user-facing string is in `config/locales`.

## Linting

```bash
pnpm lint            # eslint, prettier, stylelint (pnpm lint:fix to fix)
bundle exec rubocop  # rubocop-discourse
bundle exec stree check $(git ls-files '*.rb' '*.rake')   # syntax_tree formatting
bundle exec stree write $(git ls-files '*.rb' '*.rake')   # apply formatting
```

The configuration is copied from `discourse-plugin-skeleton`. Keep
`package.json` `devDependencies` and `pnpm-lock.yaml` in sync (run `pnpm install`
after editing), because CI installs with `--frozen-lockfile`.
