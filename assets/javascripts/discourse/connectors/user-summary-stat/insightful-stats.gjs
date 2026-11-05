import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DUserStat from "discourse/ui-kit/d-user-stat";

export default class InsightfulStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      {{#if @outletArgs.model.can_see_user_actions}}
        <li class="stats-insightful-given linked-stat">
          <LinkTo @route="userActivity.insightfulGiven">
            <DUserStat
              @icon="lightbulb"
              @label="user.summary.insightful_given"
              @value={{@outletArgs.model.insightful_given}}
            />
          </LinkTo>
        </li>
      {{else}}
        <li class="stats-insightful-given">
          <DUserStat
            @icon="lightbulb"
            @label="user.summary.insightful_given"
            @value={{@outletArgs.model.insightful_given}}
          />
        </li>
      {{/if}}
      <li class="stats-insightful-received">
        <DUserStat
          @icon="lightbulb"
          @label="user.summary.insightful_received"
          @value={{@outletArgs.model.insightful_received}}
        />
      </li>
    {{/if}}
  </template>
}
