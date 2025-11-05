import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "insightful-icons",

  initialize() {
    withPluginApi("1.6.0", (api) => {
      // Register insightful icons in the icon library
      api.replaceIcon("d-uninsightful", "far-lightbulb");
      api.replaceIcon("d-insightful", "lightbulb");

      // Add custom CSS classes for different icon states
      api.onPageChange(() => {
        const style = document.createElement("style");
        style.textContent = `
          /* Uninsightful state - outline lightbulb */
          .d-icon-far-lightbulb {
            color: var(--primary-medium);
          }
          
          /* Insightful state - solid lightbulb */  
          .d-icon-lightbulb {
            color: var(--tertiary);
          }
          
          /* Hover states */
          .insightful:hover .d-icon-far-lightbulb,
          .insightful:hover .d-icon-lightbulb {
            color: var(--tertiary);
          }
          
          .has-insightful:hover .d-icon-lightbulb {
            color: var(--primary-medium);
          }
          
          /* Disabled state */
          .toggle-insightful[disabled] .d-icon {
            color: var(--primary-medium);
          }
          
          /* Animation support */
          .lightbulb-animation .d-icon {
            transform-origin: center;
          }
        `;

        if (!document.querySelector("#insightful-icon-styles")) {
          style.id = "insightful-icon-styles";
          document.head.appendChild(style);
        }
      });
    });
  },
};
