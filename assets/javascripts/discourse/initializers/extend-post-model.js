import { _addTrackedPostProperty } from "discourse/models/post";

export default {
  name: "extend-post-model-for-insightful",

  initialize() {
    // Add tracked properties for insightful
    _addTrackedPostProperty("insightfulAction");
    _addTrackedPostProperty("insightful_count");
    _addTrackedPostProperty("insightfuled");
    _addTrackedPostProperty("can_toggle_insightful");
  },
};
