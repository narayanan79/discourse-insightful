# Testing

Plugin tests run inside a Discourse checkout with plugins loaded.

```bash
# from the discourse root, with this plugin in plugins/discourse-insightful
LOAD_PLUGINS=1 bin/rspec plugins/discourse-insightful/spec            # backend + system
LOAD_PLUGINS=1 bin/rspec plugins/discourse-insightful/spec/requests   # one directory
bin/rake "plugin:qunit[discourse-insightful]"                         # frontend
bin/qunit plugins/discourse-insightful/test/javascripts               # frontend (dev server)
```

CI runs the same suites through `discourse/.github`'s reusable plugin workflow
(`.github/workflows/discourse-plugin.yml`): linting, RSpec, QUnit, system specs,
Zeitwerk checks and a `SKIP_DB_AND_REDIS` boot check.

## What is covered

| Area | File | Covers |
| --- | --- | --- |
| Mark service | `spec/services/insightful_action_creator_spec.rb` | contract; missing post; own post; anonymous; invisible PM; closed topic; trust level; deleted author; duplicate; core refusal and a failing last write both roll back every earlier write; stats, user actions, daily count, MessageBus payload, `insightfuled_by` hidden when the setting is off, event; PM not counted in stats |
| Unmark service | `spec/services/insightful_action_destroyer_spec.rb` | contract; missing post/action; undo window; removal; exact stats decrement; PM symmetry; actions created before user-action logging; MessageBus, event |
| HTTP | `spec/requests/insightful_controller_spec.rb` | login, plugin disabled (404); response shape; hidden post reveals nothing; duplicate (422); read-only lock (503); daily limit counts only successes; undo window (403); who-actioned order, real total, ignored users, setting, visibility |
| Core endpoint guards | `spec/requests/post_actions_controller_spec.rb` | `/post_actions` refuses type 51, also when the plugin is disabled; `/post_action_users` refuses type 51; likes unaffected |
| User summary | `spec/requests/users_controller_spec.rb` | fresh stats for owner and anonymous viewers after a mark; core user serializer hides names; lists omitted when empty |
| Serializer | `spec/serializers/post_serializer_spec.rb` | field values; undo window; closed topic and own post; plugin disabled; no per-post lookup in a topic view, with a positive control |
| Directory | `spec/integration/directory_columns_spec.rb` | counts exclude PMs; columns follow the plugin toggle; admin choice survives refresh |
| User deletion | `spec/integration/user_destroyer_spec.rb` | deleting a user who marked posts works; daily rows removed |
| Daily table | `spec/models/insightful_daily_spec.rb`, `spec/jobs/cleanup_insightful_daily_spec.rb` | upsert, decrement by day, floor at zero, retention |
| Rake | `spec/tasks/insightful_tasks_spec.rb` | recalculation repairs drift; backfill survives deleted posts |
| UI (browser) | `spec/system/insightful_button_spec.rb`, `spec/system/core_features_spec.rb` | mark/unmark, who list, real-time update, anonymous login; core features still work |
| Component | `test/javascripts/integration/components/insightful-button-test.gjs` | rendering states, toggle, server errors, disabled state, who list, `shouldRender`, anonymous login |
| App | `test/javascripts/acceptance/insightful-test.js` | topic page mark, MessageBus updates before and after a toggle, same user in another tab, who list, anonymous redirect, activity empty states |

## Verification status

CI runs the suites on every pull request and on every push to `main`.

## Writing tests

- Follow core's `.skills/discourse-writing-rspec-tests`. For services:
  `subject(:result) { described_class.call(params:, **dependencies) }` with the
  `fail_a_policy` / `run_successfully` matchers.
- In request specs, do not name a fabricated record `post`. It shadows the
  `post "/path"` request helper.
- Use `DiscourseEvent.track_events` and `MessageBus.track_publish` instead of
  mocking `trigger` or `publish`.
- Test files end in `-test.js` / `-test.gjs` (enforced by lint).
