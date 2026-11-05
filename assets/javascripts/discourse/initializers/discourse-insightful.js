import { withPluginApi } from "discourse/lib/plugin-api";
import InsightfulButton from "../components/insightful-button.gjs";

const MESSAGE_TYPES = ["insightfuled", "uninsightfuled"];

export default {
  name: "discourse-insightful",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.insightful_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addTrackedPostProperties(
        "insightful_count",
        "insightfuled",
        "can_toggle_insightful"
      );

      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post } }) => {
          if (post) {
            dag.add("insightful", InsightfulButton, {
              before: ["reply", "share", "flag"],
            });
          }
          return dag;
        }
      );

      // One handler per message type for the whole topic, instead of one
      // MessageBus subscription per rendered post.
      MESSAGE_TYPES.forEach((type) => {
        api.registerCustomPostMessageCallback(type, (topicController, data) => {
          const post = topicController
            .get("model.postStream")
            ?.findLoadedPost(data.id);

          if (!post || data.insightful_count === undefined) {
            return;
          }

          post.insightful_count = data.insightful_count;

          // The same user acting from another tab or device.
          if (data.insightfuled_by === api.getCurrentUser()?.id) {
            post.insightfuled = type === "insightfuled";
          }
        });
      });
    });
  },
};
