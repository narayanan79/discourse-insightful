export default {
  resource: "user.userActivity",
  map() {
    this.route("insightfulGiven", { path: "insightful-given" });
    this.route("insightfulReceived", { path: "insightful-received" });
  },
};
