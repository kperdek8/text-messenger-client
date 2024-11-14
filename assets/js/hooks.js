const Hooks = {};

// Define your SubmitLogoutForm hook
Hooks.SubmitLogoutForm = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      document.getElementById("logout-form").submit();
    });
  },
};

Hooks.SubmitLoginForm = {
  mounted() {
    this.handleEvent("trigger_login_post", ({ token }) => {
      console.log("Test123");
      const hiddenForm = document.getElementById("hidden-login-form");
      const tokenInput = document.getElementById("token-input");

      tokenInput.value = token; // Set the token in a hidden field
      hiddenForm.submit();
    });
  },
};

// Export the Hooks object
export default Hooks;
