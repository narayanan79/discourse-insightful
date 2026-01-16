import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import UserStat from "discourse/components/user-stat";

export default class InsightfulStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      {{#if @outletArgs.model.insightful_given}}
        <li class="user-summary-stat-outlet insightful-given linked-stat">
          <LinkTo @route="userActivity.insightfulGiven">
            <UserStat
              @value={{@outletArgs.model.insightful_given}}
              @label="user.summary.insightful_given.other"
              @icon="lightbulb"
            />
          </LinkTo>
        </li>
      {{/if}}
      {{#if @outletArgs.model.insightful_received}}
        <li class="user-summary-stat-outlet insightful-received linked-stat">
          <LinkTo @route="userActivity.insightfulReceived">
            <UserStat
              @value={{@outletArgs.model.insightful_received}}
              @label="user.summary.insightful_received.other"
              @icon="lightbulb"
            />
          </LinkTo>
        </li>
      {{/if}}
    {{/if}}
  </template>
}
