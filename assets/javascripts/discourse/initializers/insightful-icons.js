import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "insightful-icons",

  initialize() {
    withPluginApi("1.6.0", (api) => {
      // Register insightful icons in the icon library
      api.replaceIcon("d-uninsightful", "far-lightbulb");
      api.replaceIcon("d-insightful", "lightbulb");

      // Note: Icon styles have been moved to insightful.scss
      // No need for dynamic CSS injection
    });
  },
};
