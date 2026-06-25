import "./styles.css";

declare global {
  interface ImportMeta {
    readonly hot?: {
      accept(): void;
    };
  }
}

const status = document.createElement("p");
status.className = "asset-status";
status.textContent = "Volt assets loaded.";

document.addEventListener("DOMContentLoaded", () => {
  document.body.appendChild(status);
});

if (import.meta.hot) {
  import.meta.hot.accept();
}
