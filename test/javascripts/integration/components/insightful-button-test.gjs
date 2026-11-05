import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import InsightfulButton from "discourse/plugins/discourse-insightful/discourse/components/insightful-button";

// Stand-in for the Post model with the properties the plugin tracks.
class TestPost {
  @tracked insightful_count = 0;
  @tracked insightfuled = false;
  @tracked can_toggle_insightful = true;

  id = 1;
  show_insightful = true;
  topic = { archived: false };

  constructor(attrs = {}) {
    Object.assign(this, attrs);
  }
}

module(
  "Discourse Insightful | Integration | Component | insightful-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.insightful_show_who_actioned = true;
    });

    test("renders an enabled button for a post the user can mark", async function (assert) {
      this.post = new TestPost();

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );

      assert
        .dom(".post-action-menu__insightful")
        .hasClass("insightful")
        .isNotDisabled();
      assert.dom(".insightful-count").doesNotExist("no count when zero");
    });

    test("marks the post and updates the post model", async function (assert) {
      this.post = new TestPost();
      pretender.post("/insightful/1", () =>
        response({
          success: true,
          insightful_count: 1,
          insightfuled: true,
          can_toggle_insightful: true,
        })
      );

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__insightful");

      assert.dom(".post-action-menu__insightful").hasClass("has-insightful");
      assert.dom(".insightful-count").hasText("1");
      assert.true(this.post.insightfuled, "post model is updated");
    });

    test("unmarks a post the user has marked", async function (assert) {
      this.post = new TestPost({ insightful_count: 1, insightfuled: true });
      pretender.delete("/insightful/1", () =>
        response({
          success: true,
          insightful_count: 0,
          insightfuled: false,
          can_toggle_insightful: true,
        })
      );

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__insightful");

      assert.dom(".post-action-menu__insightful").hasClass("insightful");
      assert.dom(".insightful-count").doesNotExist();
    });

    test("shows later count changes made outside the component", async function (assert) {
      this.post = new TestPost();
      pretender.post("/insightful/1", () =>
        response({
          success: true,
          insightful_count: 1,
          insightfuled: true,
          can_toggle_insightful: true,
        })
      );

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__insightful");

      // e.g. a MessageBus update after someone else marked the post
      this.post.insightful_count = 2;
      await settled();

      assert.dom(".insightful-count").hasText("2");
    });

    test("shows the server's error message and keeps the state", async function (assert) {
      this.post = new TestPost();
      const dialog = getOwner(this).lookup("service:dialog");
      const alert = sinon.stub(dialog, "alert");
      pretender.post("/insightful/1", () =>
        response(403, { success: false, errors: ["Not allowed here"] })
      );

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__insightful");

      assert.true(alert.calledWith("Not allowed here"), "shows the message");
      assert.dom(".post-action-menu__insightful").hasClass("insightful");
      assert.false(this.post.insightfuled);
    });

    test("is disabled when the user cannot toggle", async function (assert) {
      this.post = new TestPost({
        insightful_count: 1,
        insightfuled: true,
        can_toggle_insightful: false,
      });

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );

      assert.dom(".post-action-menu__insightful").isDisabled();
      assert
        .dom(".post-action-menu__insightful")
        .hasAttribute("title", i18n("post.controls.has_insightfuled"));
    });

    test("lists who marked the post when the count is clicked", async function (assert) {
      this.post = new TestPost({ insightful_count: 1 });
      pretender.get("/insightful/1/who", () =>
        response({
          users: [{ id: 2, username: "sam", avatar_template: "/a/{size}.png" }],
          total_count: 1,
        })
      );

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );
      await click(".insightful-count");

      assert.dom(".who-insightfuled").hasClass("--expanded");
      assert.dom(".who-insightfuled [data-user-card='sam']").exists();
    });

    test("does not offer the list when the site hides it", async function (assert) {
      this.siteSettings.insightful_show_who_actioned = false;
      this.post = new TestPost({ insightful_count: 1 });

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );

      assert.dom(".insightful-count").isDisabled();
    });

    test("shows only the count when the button is not shown", async function (assert) {
      this.post = new TestPost({ insightful_count: 2, show_insightful: false });

      await render(
        <template><InsightfulButton @post={{this.post}} /></template>
      );

      assert.dom(".post-action-menu__insightful").doesNotExist();
      assert.dom(".insightful-count").hasText("2");
    });

    test("shouldRender", function (assert) {
      assert.true(
        InsightfulButton.shouldRender({ post: new TestPost() }),
        "renders when the button is shown"
      );
      assert.true(
        InsightfulButton.shouldRender({
          post: new TestPost({ show_insightful: false, insightful_count: 1 }),
        }),
        "renders the count of existing marks"
      );
      assert.false(
        InsightfulButton.shouldRender({
          post: new TestPost({ show_insightful: false }),
        }),
        "renders nothing otherwise"
      );
    });
  }
);

module(
  "Discourse Insightful | Integration | Component | insightful-button | anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("asks anonymous users to log in instead of sending a request", async function (assert) {
      this.post = new TestPost({ can_toggle_insightful: false });
      this.showLogin = sinon.spy();
      const request = sinon.spy();
      pretender.post("/insightful/1", () => {
        request();
        return response({});
      });

      await render(
        <template>
          <InsightfulButton
            @buttonActions={{hash showLogin=this.showLogin}}
            @post={{this.post}}
          />
        </template>
      );
      await click(".post-action-menu__insightful");

      assert.true(this.showLogin.calledOnce, "login is requested");
      assert.false(request.called, "no request is sent");
    });
  }
);
