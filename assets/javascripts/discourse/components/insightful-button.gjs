import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import SmallUserList, { smallUserAttrs } from "discourse/components/small-user-list";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import { and, eq } from "truth-helpers";

export default class InsightfulButton extends Component {
  static shouldRender(args) {
    return args.post.show_insightful || args.post.insightful_count > 0;
  }

  @service currentUser;
  @service messageBus;
  @service dialog;

  @tracked isAnimated = false;
  @tracked isLoading = false;
  
  // Local state for avatar display
  @tracked isWhoActionedVisible = false;
  @tracked actionedUsers = [];
  @tracked totalActionedUsers = 0;
  
  // Local state to track insightful properties (override post properties if needed)
  @tracked localActioned = null;
  @tracked localCanToggleInsightful = null;
  @tracked localInsightfulCount = null;

  constructor() {
    super(...arguments);
    // Bind the callback to maintain 'this' context
    this.boundOnPostUpdate = this.onPostUpdate.bind(this);
    this.subscribeToUpdates();
  }

  willDestroy() {
    super.willDestroy();
    this.unsubscribeFromUpdates();
  }

  get actioned() {
    // During loading, preserve the visual state by using local override
    const result = this.localActioned !== null ? this.localActioned : this.args.post.insightfuled;
    return result;
  }
  
  get canToggleInsightful() {
    const result = this.localCanToggleInsightful !== null ? this.localCanToggleInsightful : this.args.post.can_toggle_insightful;
    return result;
  }
  
  get insightfulCount() {
    return this.localInsightfulCount !== null ? this.localInsightfulCount : this.args.post.insightful_count;
  }

  get disabled() {
    const result = this.currentUser && !this.canToggleInsightful;
    return result;
  }

  get isDisabled() {
    return this.disabled || this.isLoading;
  }

  subscribeToUpdates() {
    if (!this.messageBus || !this.args.post || !this.args.post.topic) return;

    const channelName = `/topic/${this.args.post.topic.id}`;
    this._channelName = channelName;
    
    this.messageBus.subscribe(
      channelName,
      this.boundOnPostUpdate
    );
  }

  unsubscribeFromUpdates() {
    if (!this.messageBus || !this._channelName) return;

    this.messageBus.unsubscribe(this._channelName, this.boundOnPostUpdate);
  }

  onPostUpdate(data) {
    if (!data || !this.args || !this.args.post) {
      return;
    }

    // Only handle updates for this specific post
    if (data.id !== this.args.post.id) {
      return;
    }

    // Handle insightful updates (mirror Like behavior)
    if ((data.type === 'insightfuled' || data.type === 'uninsightfuled') && data.insightful_count !== undefined) {
      this.args.post.insightful_count = data.insightful_count;
      
      // Update the actioned state for the current user, but NOT during loading
      // This prevents visual flicker during API calls
      if (data.insightfuled_by === this.currentUser?.id && !this.isLoading) {
        const isActioned = data.type === 'insightfuled';
        this.args.post.insightfuled = isActioned;
        // Note: can_toggle_insightful will be updated via server response
        // when user performs action, not through MessageBus
      }
      
      // For other users' actions, we only update the count
      // The current user's actioned state remains unchanged
    }
  }

  get title() {
    // If the user has already actioned the post and doesn't have permission
    // to undo that operation, then indicate via the title that they've actioned it
    // and disable the button. Otherwise, set the title even if the user
    // is anonymous (meaning they don't currently have permission to insightful);
    // this is important for accessibility.

    if (this.actioned && !this.canToggleInsightful) {
      return "post.controls.has_insightfuled";
    }

    return this.actioned
      ? "post.controls.undo_insightful"
      : "post.controls.insightful";
  }

  @action
  async toggleInsightful() {
    if (this.isLoading) {
      return;
    }

    // Capture current state before any changes
    const wasActioned = this.actioned;
    const currentCanToggle = this.canToggleInsightful;
    const currentCount = this.insightfulCount;

    // Immediately set local state to freeze the visual appearance
    // This prevents ANY external updates from changing the UI during loading
    this.localActioned = wasActioned;
    this.localCanToggleInsightful = currentCanToggle;
    this.localInsightfulCount = currentCount;

    this.isAnimated = true;
    this.isLoading = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;

        try {
          let response;
          if (wasActioned) {
            response = await ajax(`/insightful/${this.args.post.id}`, {
              type: "DELETE"
            });
          } else {
            response = await ajax(`/insightful/${this.args.post.id}`, {
              type: "POST"
            });
          }

          if (response.success) {
            // Now update to the new state based on API response
            this.localInsightfulCount = response.insightful_count;
            // Handle both old and new response formats
            this.localActioned = response.insightfuled !== undefined ? response.insightfuled : response.acted;
            // Handle both old and new property names for backward compatibility  
            this.localCanToggleInsightful = response.can_toggle_insightful || response.can_undo_insightful;
            
            // Also update post properties for other components
            this.args.post.insightful_count = response.insightful_count;
            // Update post actioned state after API response
            this.args.post.insightfuled = this.localActioned;
            
            // Refresh avatar list if visible
            if (this.isWhoActionedVisible) {
              await this.fetchWhoActioned();
            }
          }
        } catch (error) {
          // On error, reset local state to let post state show through
          this.localActioned = null;
          this.localCanToggleInsightful = null;
          this.localInsightfulCount = null;

          // Extract error message directly from response to avoid "An error occurred:" prefix
          let errorMessage = extractError(error);
          if (error.jqXHR?.responseJSON?.errors) {
            errorMessage = error.jqXHR.responseJSON.errors[0];
          }
          this.dialog.alert(errorMessage);
        } finally {
          this.isLoading = false;
          resolve();
        }
      }, 400);
    });
  }

  get remainingActionedUsers() {
    return Math.max(0, (this.totalActionedUsers || 0) - (this.actionedUsers?.length || 0));
  }

  @action
  async toggleWhoActioned() {
    if (this.isWhoActionedVisible) {
      this.isWhoActionedVisible = false;
      return;
    }

    await this.fetchWhoActioned();
  }

  @action
  closeWhoActioned() {
    this.isWhoActionedVisible = false;
  }

  async fetchWhoActioned() {
    try {
      const response = await ajax(`/insightful/${this.args.post.id}/who`);

      this.actionedUsers = response.users.map(smallUserAttrs);
      this.totalActionedUsers = response.total_count;
      this.isWhoActionedVisible = true;
    } catch (error) {
      this.dialog.alert(extractError(error));
    }
  }

  <template>
    {{#if @post.show_insightful}}
      <div class="double-button">
        <div
          class={{concatClass
            "discourse-insightful-button"
            (if this.disabled "my-post")
          }}
        >
          <InsightfulCount
            ...attributes
            @post={{@post}}
            @actioned={{this.actioned}}
            @insightfulCount={{this.insightfulCount}}
            @action={{this.toggleWhoActioned}}
            @isWhoActionedVisible={{this.isWhoActionedVisible}}
          />
          <DButton
            class={{concatClass
              "post-action-menu__insightful"
              "toggle-insightful"
              "btn-icon"
              (if this.isAnimated "check-animation")
              (if this.actioned "has-insightful" "insightful")
              (if this.actioned "insightful-by-me")
              (if this.isLoading "loading")
            }}
            ...attributes
            data-post-id={{@post.id}}
            disabled={{this.isDisabled}}
            @action={{this.toggleInsightful}}
            @icon="lightbulb"
            @title={{this.title}}
          />
        </div>
        {{#if this.insightfulCount}}
          <SmallUserList
            class="who-actioned"
            @addSelf={{and this.actioned (eq this.remainingActionedUsers 0)}}
            @isVisible={{this.isWhoActionedVisible}}
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
            @users={{this.actionedUsers}}
            {{(if
              this.isWhoActionedVisible
              (modifier
                closeOnClickOutside
                (fn this.closeWhoActioned)
                (hash targetSelector=".insightful-count")
              )
            )}}
          />
        {{/if}}
      </div>
    {{else}}
      <div class="double-button">
        <InsightfulCount
          ...attributes
          @post={{@post}}
          @actioned={{this.actioned}}
          @insightfulCount={{this.insightfulCount}}
          @action={{this.toggleWhoActioned}}
          @isWhoActionedVisible={{this.isWhoActionedVisible}}
        />
        {{#if this.insightfulCount}}
          <SmallUserList
            class="who-actioned"
            @addSelf={{and this.actioned (eq this.remainingActionedUsers 0)}}
            @isVisible={{this.isWhoActionedVisible}}
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
            @users={{this.actionedUsers}}
            {{(if
              this.isWhoActionedVisible
              (modifier
                closeOnClickOutside
                (fn this.closeWhoActioned)
                (hash targetSelector=".insightful-count")
              )
            )}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}

class InsightfulCount extends Component {
  // No icon in count - only show the number like the like button

  get actioned() {
    return this.args.actioned !== undefined ? this.args.actioned : this.args.post.insightfuled;
  }
  
  get insightfulCount() {
    return this.args.insightfulCount !== undefined ? this.args.insightfulCount : this.args.post.insightful_count;
  }

  get translatedTitle() {
    let title;

    if (this.actioned) {
      title =
        this.insightfulCount === 1
          ? "post.has_insightfuls_title_only_you"
          : "post.has_insightfuls_title_you";
    } else {
      title = "post.has_insightfuls_title";
    }

    return i18n(title, {
      count: this.actioned
        ? this.insightfulCount - 1
        : this.insightfulCount,
    });
  }

  @action
  toggleWhoActioned() {
    if (this.args.action) {
      this.args.action();
    }
  }

  <template>
    {{#if this.insightfulCount}}
      <button
        class={{concatClass
          "post-action-menu__insightful-count"
          "insightful-count"
          "button-count"
          "highlight-action"
          (if this.actioned "my-insightfuls" "regular-insightfuls")
        }}
        ...attributes
        title={{this.translatedTitle}}
        {{on "click" this.toggleWhoActioned}}
        type="button"
        aria-pressed={{@isWhoActionedVisible}}
      >
        {{this.insightfulCount}}
      </button>
    {{/if}}
  </template>
}