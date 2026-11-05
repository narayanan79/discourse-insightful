import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserSummarySection from "discourse/components/user-summary-section";
import UserSummaryUser from "discourse/components/user-summary-user";
import UserSummaryUsersList from "discourse/components/user-summary-users-list";

export default class InsightfulSummarySections extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.insightful_enabled}}
      <div class="top-section most-insightful-section">
        <UserSummarySection
          class="summary-user-list insightful-received-by-section pull-left"
          @title="most_insightful_received_by"
        >
          <UserSummaryUsersList
            @none="no_insightfuls"
            @users={{@outletArgs.model.most_insightful_received_by_users}}
            as |user|
          >
            <UserSummaryUser
              @countClass="insightfuls"
              @icon="lightbulb"
              @user={{user}}
            />
          </UserSummaryUsersList>
        </UserSummarySection>

        <UserSummarySection
          class="summary-user-list insightful-given-section pull-right"
          @title="most_insightful_given_to_users"
        >
          <UserSummaryUsersList
            @none="no_insightfuls"
            @users={{@outletArgs.model.most_insightful_given_to_users}}
            as |user|
          >
            <UserSummaryUser
              @countClass="insightfuls"
              @icon="lightbulb"
              @user={{user}}
            />
          </UserSummaryUsersList>
        </UserSummarySection>
      </div>
    {{/if}}
  </template>
}
