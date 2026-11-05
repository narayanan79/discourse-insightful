import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { and, eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DSmallUserList, {
  smallUserAttrs,
} from "discourse/ui-kit/d-small-user-list";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";

const InsightfulCount = <template>
  <button
    aria-expanded={{if @expanded "true" "false"}}
    aria-label={{i18n "post.sr_post_insightful_count_button" count=@count}}
    class={{dConcatClass
      "post-action-menu__insightful-count"
      "insightful-count"
      "button-count"
      "highlight-action"
      (if @insightfuled "my-insightfuls" "regular-insightfuls")
      (unless @clickable "who-insightfuled-disabled")
    }}
    disabled={{not @clickable}}
    id={{@elementId}}
    title={{@title}}
    type="button"
    ...attributes
    {{on "click" @onClick}}
  >
    {{@count}}
  </button>
</template>;

/**
 * Post menu button to mark a post as insightful, with its count and the list
 * of users who marked it.
 *
 * The tracked post properties (`insightful_count`, `insightfuled`,
 * `can_toggle_insightful`) are the single source of truth: they are updated
 * from the server response and from MessageBus (see the initializer), so the
 * button never shows stale local state.
 */
export default class InsightfulButton extends Component {
  static shouldRender(args) {
    return args.post.show_insightful || args.post.insightful_count > 0;
  }

  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked isAnimated = false;
  @tracked isLoading = false;
  @tracked isWhoActionedVisible = false;
  @tracked actionedUsers = [];
  @tracked totalActionedUsers = 0;

  get insightfulCount() {
    return this.args.post.insightful_count || 0;
  }

  get insightfuled() {
    return !!this.args.post.insightfuled;
  }

  get canToggle() {
    return !!this.args.post.can_toggle_insightful;
  }

  get disabled() {
    if (this.isLoading) {
      return true;
    }

    // Anonymous users get the login prompt, except where nobody could act.
    if (!this.currentUser) {
      return !!this.args.post.topic?.archived;
    }

    return !this.canToggle;
  }

  get canShowWhoActioned() {
    return !!(
      this.currentUser && this.siteSettings.insightful_show_who_actioned
    );
  }

  get countElementId() {
    return `insightful-count-${this.args.post.id}`;
  }

  get remainingActionedUsers() {
    return Math.max(0, this.totalActionedUsers - this.actionedUsers.length);
  }

  get title() {
    if (this.insightfuled && !this.canToggle) {
      return "post.controls.has_insightfuled";
    }

    return this.insightfuled
      ? "post.controls.undo_insightful"
      : "post.controls.insightful";
  }

  get countTitle() {
    const count = this.insightfulCount;

    if (!this.insightfuled) {
      return i18n("post.has_insightfuls_title", { count });
    }

    return count === 1
      ? i18n("post.has_insightfuls_title_only_you")
      : i18n("post.has_insightfuls_title_you", { count: count - 1 });
  }

  @action
  toggleInsightful() {
    if (!this.currentUser) {
      this.args.buttonActions?.showLogin?.();
      return;
    }

    if (this.isLoading) {
      return;
    }

    this.isAnimated = true;
    this.isLoading = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;

        try {
          await this.#toggle();
        } finally {
          this.isLoading = false;
          resolve();
        }
      }, 400);
    });
  }

  @action
  async toggleWhoActioned() {
    if (this.isWhoActionedVisible) {
      this.isWhoActionedVisible = false;
      return;
    }

    await this.#loadWhoActioned();
  }

  @action
  closeWhoActioned() {
    this.isWhoActionedVisible = false;
  }

  async #toggle() {
    const post = this.args.post;

    try {
      const result = await ajax(`/insightful/${post.id}`, {
        type: this.insightfuled ? "DELETE" : "POST",
      });

      post.insightful_count = result.insightful_count;
      post.insightfuled = result.insightfuled;
      post.can_toggle_insightful = result.can_toggle_insightful;

      if (this.isWhoActionedVisible) {
        await this.#loadWhoActioned();
      }
    } catch (error) {
      this.dialog.alert(this.#errorMessage(error));
    }
  }

  async #loadWhoActioned() {
    try {
      const result = await ajax(`/insightful/${this.args.post.id}/who`);

      this.actionedUsers = result.users.map(smallUserAttrs);
      this.totalActionedUsers = result.total_count;
      this.isWhoActionedVisible = true;
    } catch (error) {
      this.dialog.alert(this.#errorMessage(error));
    }
  }

  // The server sends user-facing messages; avoid the generic "An error
  // occurred:" prefix that extractError adds to them.
  #errorMessage(error) {
    return error.jqXHR?.responseJSON?.errors?.[0] ?? extractError(error);
  }

  <template>
    <div class="double-button">
      {{#if @post.show_insightful}}
        <div
          class={{dConcatClass
            "discourse-insightful-button"
            (if this.disabled "my-post")
          }}
        >
          {{#if this.insightfulCount}}
            <InsightfulCount
              ...attributes
              @clickable={{this.canShowWhoActioned}}
              @count={{this.insightfulCount}}
              @elementId={{this.countElementId}}
              @expanded={{this.isWhoActionedVisible}}
              @insightfuled={{this.insightfuled}}
              @onClick={{this.toggleWhoActioned}}
              @title={{this.countTitle}}
            />
          {{/if}}
          <DButton
            class={{dConcatClass
              "post-action-menu__insightful"
              "toggle-insightful"
              "btn-icon"
              (if this.isAnimated "check-animation")
              (if this.insightfuled "has-insightful" "insightful")
              (if this.insightfuled "insightful-by-me")
              (if this.isLoading "loading")
            }}
            ...attributes
            data-post-id={{@post.id}}
            @action={{this.toggleInsightful}}
            @ariaLabel={{this.title}}
            @disabled={{this.disabled}}
            @icon="lightbulb"
            @title={{this.title}}
          />
        </div>
      {{else if this.insightfulCount}}
        <InsightfulCount
          ...attributes
          @clickable={{this.canShowWhoActioned}}
          @count={{this.insightfulCount}}
          @elementId={{this.countElementId}}
          @expanded={{this.isWhoActionedVisible}}
          @insightfuled={{this.insightfuled}}
          @onClick={{this.toggleWhoActioned}}
          @title={{this.countTitle}}
        />
      {{/if}}

      {{#if this.insightfulCount}}
        <DSmallUserList
          class="who-insightfuled"
          @addSelf={{and this.insightfuled (eq this.remainingActionedUsers 0)}}
          @count={{if
            this.remainingActionedUsers
            this.remainingActionedUsers
            this.totalActionedUsers
          }}
          @description={{if
            this.remainingActionedUsers
            "post.actions.people.insightful_capped"
            "post.actions.people.insightful"
          }}
          @isVisible={{this.isWhoActionedVisible}}
          @users={{this.actionedUsers}}
          {{(if
            this.isWhoActionedVisible
            (modifier
              dCloseOnClickOutside
              this.closeWhoActioned
              (hash targetSelector=(concat "#" this.countElementId))
            )
          )}}
        />
      {{/if}}
    </div>
  </template>
}
