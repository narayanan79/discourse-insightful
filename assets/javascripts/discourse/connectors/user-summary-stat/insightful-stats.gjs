import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import UserStat from "discourse/components/user-stat";

export default class InsightfulStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      {{#if @outletArgs.model.can_see_user_actions}}
        <li class="stats-insightful-given linked-stat">
          <LinkTo @route="userActivity.insightfulGiven">
            <UserStat
              @value={{@outletArgs.model.insightful_given}}
              @icon="lightbulb"
              @label="user.summary.insightful_given"
            />
          </LinkTo>
        </li>
      {{else}}
        <li class="stats-insightful-given">
          <UserStat
            @value={{@outletArgs.model.insightful_given}}
            @icon="lightbulb"
            @label="user.summary.insightful_given"
          />
        </li>
      {{/if}}
      <li class="stats-insightful-received">
        <UserStat
          @value={{@outletArgs.model.insightful_received}}
          @icon="lightbulb"
          @label="user.summary.insightful_received"
        />
      </li>
    {{/if}}
  </template>
}
