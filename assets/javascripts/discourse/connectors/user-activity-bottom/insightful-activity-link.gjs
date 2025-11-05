import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/components/d-navigation-item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InsightfulActivityLink extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      <DNavigationItem
        @route="userActivity.insightfulGiven"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-insightful"
      >
        {{icon "lightbulb"}}
        <span>{{i18n "user_action_groups.20"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
