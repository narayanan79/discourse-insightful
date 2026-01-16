import UserTopicListRoute from "discourse/routes/user-topic-list";
import { action } from "@ember/object";
import I18n from "discourse-i18n";

export default class UserActivityInsightfulReceived extends UserTopicListRoute {
  userActionType = 21; // UserAction::INSIGHTFUL_RECEIVED

  @action
  didTransition() {
    this.controllerFor("user-activity")._showFooter();
    return true;
  }

  model() {
    return this.store.findFiltered("userAction", {
      username: this.modelFor("user").username,
      filter: this.userActionType,
    });
  }

  titleToken() {
    return I18n.t("user_action_groups.21");
  }
}
