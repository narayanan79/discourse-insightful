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
          @title="most_insightful_received_by"
          class="summary-user-list insightful-received-by-section pull-left"
        >
          <UserSummaryUsersList
            @none="no_insightfuls"
            @users={{@outletArgs.model.most_insightful_received_by_users}}
            as |user|
          >
            <UserSummaryUser
              @user={{user}}
              @icon="lightbulb"
              @countClass="insightfuls"
            />
          </UserSummaryUsersList>
        </UserSummarySection>

        <UserSummarySection
          @title="most_insightful_given_to_users"
          class="summary-user-list insightful-given-section pull-right"
        >
          <UserSummaryUsersList
            @none="no_insightfuls"
            @users={{@outletArgs.model.most_insightful_given_to_users}}
            as |user|
          >
            <UserSummaryUser
              @user={{user}}
              @icon="lightbulb"
              @countClass="insightfuls"
            />
          </UserSummaryUsersList>
        </UserSummarySection>
      </div>
    {{/if}}
  </template>
}
