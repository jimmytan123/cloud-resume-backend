const { defineConfig } = require('cypress');

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    baseUrl:
      'https://n90ufux0ec.execute-api.us-west-2.amazonaws.com/test', // API Gateway URL
  },
});
