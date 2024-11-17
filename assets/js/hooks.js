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

Hooks.CopyUUID = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      const text = this.el.innerText.replace("UUID: ", ""); // Extract the UUID part
      navigator.clipboard.writeText(text).then(function () {
        alert("UUID copied to clipboard!");
      }).catch(function (err) {
        alert("Failed to copy UUID: ", err);
      });
    });
  }
}

// Export the Hooks object
export default Hooks;
