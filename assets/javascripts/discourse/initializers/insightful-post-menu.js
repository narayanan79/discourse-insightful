import { withPluginApi } from "discourse/lib/plugin-api";
import InsightfulButton from "../components/insightful-button";

export default {
  name: "insightful-post-menu",

  initialize() {
    withPluginApi("1.34.0", (api) => {
      // Register insightful button using value transformer
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context }) => {
          const post = context.post;

          if (!post) {
            return dag;
          }

          // Add insightful button to the DAG
          dag.add("insightful", InsightfulButton, {
            before: ["reply", "share", "flag"],
          });

          return dag;
        }
      );
    });
  },
};
