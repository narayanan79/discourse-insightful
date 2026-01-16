import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserActivityInsightfulReceived extends UserActivityStreamRoute {
  userActionType = 21; // UserAction::INSIGHTFUL_RECEIVED

  emptyState() {
    const user = this.modelFor("user");

    const title = this.isCurrentUser(user)
      ? i18n("user_activity.no_insightful_received_title")
      : i18n("user_activity.no_insightful_received_title_others", {
          username: user.username,
        });
    const body = htmlSafe(
      i18n("user_activity.no_insightful_received_body", {
        icon: iconHTML("certificate"),
      })
    );

    return { title, body };
  }

  titleToken() {
    return i18n("user_action_groups.21");
  }
}
