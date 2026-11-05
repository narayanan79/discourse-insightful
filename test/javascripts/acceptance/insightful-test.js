import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const TOPIC_URL = "/t/internationalization-localization/280";
const FIRST_POST_ID = 398;

function topicWithInsightfuls(postAttrs = {}) {
  const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
  topic.post_stream.posts.forEach((post) =>
    Object.assign(
      post,
      {
        show_insightful: true,
        insightful_count: 0,
        insightfuled: false,
        can_toggle_insightful: true,
      },
      postAttrs
    )
  );
  return topic;
}

acceptance("Discourse Insightful | post menu", function (needs) {
  needs.user();
  needs.settings({
    insightful_enabled: true,
    insightful_show_who_actioned: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => helper.response(topicWithInsightfuls()));
    server.post(`/insightful/${FIRST_POST_ID}`, () =>
      helper.response({
        success: true,
        insightful_count: 1,
        insightfuled: true,
        can_toggle_insightful: true,
      })
    );
    server.get(`/insightful/${FIRST_POST_ID}/who`, () =>
      helper.response({
        users: [{ id: 2, username: "sam", avatar_template: "/a/{size}.png" }],
        total_count: 1,
      })
    );
  });

  test("marks a post as insightful", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__insightful");

    assert
      .dom("#post_1 .post-action-menu__insightful")
      .hasClass("has-insightful");
    assert.dom("#post_1 .insightful-count").hasText("1");
  });

  test("applies real-time updates from other users", async function (assert) {
    await visit(TOPIC_URL);

    await publishToMessageBus("/topic/280", {
      type: "insightfuled",
      id: FIRST_POST_ID,
      insightful_count: 3,
      insightfuled_by: 999,
    });

    assert.dom("#post_1 .insightful-count").hasText("3");
    assert
      .dom("#post_1 .post-action-menu__insightful")
      .hasClass("insightful", "the viewer's own state is unchanged");
  });

  test("keeps applying real-time updates after the user toggled", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__insightful");

    await publishToMessageBus("/topic/280", {
      type: "insightfuled",
      id: FIRST_POST_ID,
      insightful_count: 4,
      insightfuled_by: 999,
    });

    assert.dom("#post_1 .insightful-count").hasText("4");
  });

  test("reflects the user's own action from another tab", async function (assert) {
    await visit(TOPIC_URL);

    await publishToMessageBus("/topic/280", {
      type: "insightfuled",
      id: FIRST_POST_ID,
      insightful_count: 1,
      insightfuled_by: 19,
    });

    assert
      .dom("#post_1 .post-action-menu__insightful")
      .hasClass("has-insightful");
  });

  test("lists who marked a post", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__insightful");
    await click("#post_1 .insightful-count");

    assert.dom("#post_1 .who-insightfuled").hasClass("--expanded");
    assert.dom("#post_1 .who-insightfuled [data-user-card='sam']").exists();
  });
});

acceptance("Discourse Insightful | post menu | anonymous", function (needs) {
  needs.settings({ insightful_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () =>
      helper.response(topicWithInsightfuls({ can_toggle_insightful: false }))
    );
  });

  test("sends anonymous visitors to the login page", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__insightful");

    assert.strictEqual(currentURL(), "/login");
  });
});

acceptance("Discourse Insightful | activity tabs", function (needs) {
  needs.user();
  needs.settings({ insightful_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/user_actions.json", () =>
      helper.response({ user_actions: [] })
    );
  });

  test("shows an empty state for insightfuls given", async function (assert) {
    await visit("/u/eviltrout/activity/insightful-given");

    assert
      .dom(".empty-state .empty-state__title")
      .hasText(i18n("user_activity.no_insightful_given_title"));
  });

  test("shows an empty state for another user's insightfuls received", async function (assert) {
    await visit("/u/charlie/activity/insightful-received");

    assert.dom(".empty-state .empty-state__title").hasText(
      i18n("user_activity.no_insightful_received_title_others", {
        username: "charlie",
      })
    );
  });
});
