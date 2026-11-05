# Architecture

This describes the plugin as implemented after the 2026-11 remediation, ported
from discourse-actionable.

## Building blocks

| Concern | Where | Notes |
| --- | --- | --- |
| Identifiers | `plugin.rb` (`DiscourseInsightful::*`) | Post action type `51`, user action types `20`/`21`. These values are persisted in the database and must never change. |
| Permission rule | `lib/guardian_extension.rb` | `Guardian#can_mark_post_insightful?`: one rule shared by the service and the serializer. |
| Mark / unmark | `lib/insightful_action_creator.rb`, `lib/insightful_action_destroyer.rb` | `Service::Base` services. |
| HTTP | `controllers/insightful_controller.rb` | Thin controller: daily limit, service result mapping, who-actioned list. |
| Serializer state | `plugin.rb` + `lib/post_serializer_extension.rb` | `insightful_count`, `insightfuled`, `can_toggle_insightful`, `can_undo_insightful`, `show_insightful`. |
| User stats | `lib/user_action_extension.rb` | `UserAction.update_like_count` maps types 18/19 to `user_stats.insightful_*`. All other types are delegated to core. |
| User summary | `lib/user_summary_extension.rb` + `plugin.rb` | Lists are serialized with core's `UserWithCountSerializer`. |
| Directory | `lib/directory_columns.rb` | Per-column refresh SQL, plus the plugin-toggle sync. |
| Summary cache | `lib/insightful_cache_helper.rb` | Deletes core's summary cache keys (format copied from `UsersController#summary_cache_key`). |
| Daily table | `lib/insightful_daily.rb`, `app/jobs/scheduled/cleanup_insightful_daily.rb` | Reporting data with 90-day retention. |
| Guards on core APIs | `lib/post_actions_controller_extension.rb`, `lib/post_action_users_controller_extension.rb` | Core's `/post_actions` and `/post_action_users` reject type 50. |
| Frontend | `assets/javascripts/discourse/` | One initializer, one button component, three connectors, two activity routes. |

## Marking a post (server)

```
InsightfulController#create
  before_action: RateLimiter can_perform? (daily limit; only success consumes a slot)
  InsightfulActionCreator
    params        post_id (integer, required)
    model         post
    policy        can_mark_post_insightful   (Guardian rule)
    lock(post_id) DistributedMutex per post (marks of one post queue up)
      policy      not_already_actioned
      transaction
        step      create_post_action         core PostActionCreator(silent); fail! on refusal
        step      log_user_actions           UserAction 18 + 19 (log_action! updates user_stats, skips PMs)
        step      track_daily_count          INSERT … ON CONFLICT DO UPDATE
        step      update_post_insightful_count   SELECT … FOR UPDATE on the post, then recount
    step          invalidate_user_summaries  after commit
    step          publish_post_change        MessageBus /topic/:id {type: "actioned", …}
    step          trigger_event              :insightful_created
```

The destroyer mirrors this. It looks up the acting user's own action (`model
:post_action`) and checks `Guardian#can_delete_post_action?`, which applies
core's undo window. It deletes the user-action rows and subtracts from
`user_stats` only the rows actually deleted, and never for PMs, matching what
`log_action!` counted.

### Why a lock and a transaction

- **Transaction:** all bookkeeping commits or rolls back together, so a failure
  can no longer leave a `post_action` without its stats.
- **Lock:** core's `PostActionCreator` recovers from a duplicate insert by
  catching `RecordNotUnique` without a savepoint. Inside a transaction that
  would poison the transaction. Serializing per post makes the "already
  actioned" check reliable, so the duplicate insert cannot happen through this
  endpoint. The service `lock` step names its lock after the service class, so
  it does not order a mark against an unmark.
- **Row lock before the recount:** `Post#update_insightful_count` takes
  `SELECT … FOR UPDATE` on the post before counting. A concurrent mark and
  unmark therefore count one after the other, and the second count sees the
  first commit. This was reproduced on PostgreSQL: without the lock, two
  overlapping sessions stored a count of 2 for 1 real mark; with it, the stored
  count was correct in every run.
- **Side effects run after commit:** clients never see a count that was later
  rolled back.

## Rendering (client)

- `initializers/discourse-insightful.js` (runs only when the plugin is enabled):
  - registers the tracked post properties (`insightful_count`, `insightfuled`,
    `can_toggle_insightful`);
  - adds the button through the `post-menu-buttons` value transformer;
  - registers one `registerCustomPostMessageCallback` per message type, which
    updates the post model in the topic's post stream.
- `components/insightful-button.gjs` reads only the tracked post properties and
  writes the server response back to them. There is no local copy of server
  state. Anonymous users get `buttonActions.showLogin()`.

## Serializer cost

Inside a topic view, `PostSerializer#actions` already contains the viewer's
post actions for every post (`TopicView#all_post_actions`). The extension reads
type 50 from that data, so serializing a topic adds no query per post. Outside a
topic view (for example the controller response) it runs one `find_by`.

## Directory columns

`DirectoryColumns.query` aggregates only the requested action type in a
`MATERIALIZED` CTE, so PostgreSQL uses an `(action_type, …)` index on
`user_actions`. It then applies core's countable-post rules and rewrites only
the rows whose value changed. Core runs these queries for each period during
`DirectoryItem.refresh!`.

Measured on PostgreSQL 16 with 1,020,000 `user_actions` (20,000 insightful):
the original query took 380–454 ms per column with a full table scan. The new
query takes about 50 ms for "all time" and about 10 ms for "weekly", and the
results match an independent reference query on every row.

## Data model

| Table / column | Written by | Read by |
| --- | --- | --- |
| `post_actions` (type 50) | `PostActionCreator`, `remove_act!` | serializer, who-actioned, recounts |
| `posts.insightful_count` | `Post#update_insightful_count` | serializer |
| `user_actions` (18, 19) | `UserAction.log_action!`, destroyer | activity tabs, summary lists, directory SQL |
| `user_stats.insightful_given/received` | `update_like_count` extension | user summary |
| `directory_items.insightful_*` | directory refresh | user directory |
| `insightful_daily` | services | reporting only (not used for limits) |
| `post_action_types` (id 50) | migration + `db/fixtures` | plugin only (core resolves types from `flags`) |

## Known limits of the design

- User-summary caches are per viewer. The plugin clears the owner's and the
  anonymous variants; other viewers see the regular one-hour expiry.
- When a user is deleted, core removes their `post_actions` and `user_actions`
  but does not run the plugin's recount, so affected counters can drift.
  `rake insightful:recalculate_stats` repairs them.
- The identifiers 50/18/19 are fixed. Another third-party plugin using the same
  numbers would conflict.
