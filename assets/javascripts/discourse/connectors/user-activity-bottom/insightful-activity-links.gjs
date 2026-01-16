import Component from "@glimmer/component";
import DNavigationItem from "discourse/components/d-navigation-item";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InsightfulActivityLinks extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      <DNavigationItem
        @route="userActivity.insightfulGiven"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-insightful-given"
      >
        {{icon "lightbulb"}}
        <span>{{i18n "user_action_groups.20"}}</span>
      </DNavigationItem>
      <DNavigationItem
        @route="userActivity.insightfulReceived"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-insightful-received"
      >
        {{icon "certificate"}}
        <span>{{i18n "user_action_groups.21"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
