import { replaceIcon } from "discourse-common/lib/icon-library";

export default {
  name: "extend-for-pm-scanner",
  initialize() {
    replaceIcon("notification.pm_scanner.notification.found", "exclamation");
  }
}