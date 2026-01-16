import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "insightful-routes",

  initialize() {
    withPluginApi("1.14.0", (api) => {
      // Register routes for insightful activity pages
      api.addUserActivityRoute("insightfulGiven", {
        path: "/activity/insightful-given",
        userActionType: 20,
      });

      api.addUserActivityRoute("insightfulReceived", {
        path: "/activity/insightful-received",
        userActionType: 21,
      });
    });
  },
};
