import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class InsightfulActivityLinks extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      <DNavigationItem
        class="user-nav__activity-insightful-given"
        @ariaCurrentContext="subNav"
        @route="userActivity.insightfulGiven"
      >
        {{dIcon "lightbulb"}}
        <span>{{i18n "user_action_groups.20"}}</span>
      </DNavigationItem>
      <DNavigationItem
        class="user-nav__activity-insightful-received"
        @ariaCurrentContext="subNav"
        @route="userActivity.insightfulReceived"
      >
        {{dIcon "lightbulb"}}
        <span>{{i18n "user_action_groups.21"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
