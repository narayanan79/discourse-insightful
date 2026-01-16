import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserActivityInsightfulGiven extends UserActivityStreamRoute {
  userActionType = 20; // UserAction::INSIGHTFUL_GIVEN

  emptyState() {
    const user = this.modelFor("user");

    const title = this.isCurrentUser(user)
      ? i18n("user_activity.no_insightful_given_title")
      : i18n("user_activity.no_insightful_given_title_others", {
          username: user.username,
        });
    const body = htmlSafe(
      i18n("user_activity.no_insightful_given_body", {
        icon: iconHTML("lightbulb"),
      })
    );

    return { title, body };
  }

  titleToken() {
    return i18n("user_action_groups.20");
  }
}
