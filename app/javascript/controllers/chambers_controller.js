import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "sidebar",
    "overlay",
    "meepleDisplay",
    "meepleContainer",
    "hoverOverlay",
    "customizeLayer",
    "detailsLayer",
  ];

  static values = {
    meepleColor: String,
    meepleImageSrc: String,
    equippedCosmetics: Array,
    unlockedCosmetics: Object,
    colorPaths: Object,
    address: Object,
    editChambersUrl: String,
  };

  connect() {
    console.log("Chambers controller connected");

    this.originalWidth = 1920;
    this.originalHeight = 1080;
    this.meepleConfig = {
      x: 350,
      y: 330,
      width: 200,
      height: 240,
      scale: 1.8,
    };

    this.cloudTimeout = null;
    this.resizeHandler = () => {
      this.updateHoverSVGPosition();
      this.updateMeeplePosition();
    };

    this.initialize();
  }

  disconnect() {
    console.log("Chambers controller disconnected");
    this.cleanup();
  }

  initialize() {
    console.log("Chambers: Initializing...");

    try {
      this.setupClickSystem();
      this.setupMeepleSystem();
      this.registerWithSiegeApp();
      return true;
    } catch (error) {
      console.error("Chambers: Initialization failed:", error);
      return false;
    }
  }

  registerWithSiegeApp() {
    if (window.SiegeApp && typeof window.SiegeBaseManager !== "undefined") {
      console.log("Registering ChambersManager with SiegeApp");
      const manager = {
        init: () => {
          /* Already initialized */
        },
        resize: () => {
          this.updateHoverSVGPosition();
          this.updateMeeplePosition();
        },
        cleanup: () => this.cleanup(),
      };
      window.SiegeApp.registerManager("chambers", manager);
    } else {
      setTimeout(() => this.registerWithSiegeApp(), 50);
    }
  }

  setupClickSystem() {
    if (!this.hasHoverOverlayTarget) return;

    this.hoverOverlayTarget.innerHTML = "";
    this.createHoverSVG();
    this.updateHoverSVGPosition();

    window.addEventListener("resize", this.resizeHandler);
  }

  setupMeepleSystem() {
    this.updateMeeplePosition();
    this.initializeMeepleDisplay();
  }

  createHoverSVG() {
    const svgElement = document.createElement("div");
    svgElement.className = "hover-box";

    const clickAreas = [
      {
        id: "details",
        path: `M57.5 58L1 119.5V165L40 175L52 198.5H66V282L57.5 299.5L79.5 316L113.5 309.5L265 322L311.5 332L327.5 322L316.5 309.5L327.5 221L362.5 207L356.5 182.5L392.5 175L386 126L321 15.5L135 1L57.5 58Z`,
        fill: "#E40000",
        fillOpacity: "0",
        stroke: "",
        x: 1085,
        y: 645,
        scale: 1,
        targetLayer: "details",
        action: "showDetailsModal",
      },
      {
        id: "customization",
        path: `M78.5 365.5L1 356.5V337.5L29 316.5L18 240.5H50.5L43.5 119L34.5 56.5L56 47L74 12.5L105 1.5L155.5 89L187.5 56.5L226 47L293.5 6L327 1.5L371.5 52V250.5L341 292.5L327 379.5H226L78.5 365.5Z`,
        fill: "#0000E4",
        fillOpacity: "0",
        stroke: "",
        x: 510,
        y: 525,
        scale: 1,
        targetLayer: "customize-character",
        action: "openSidebar",
      },
    ];

    let svgContent = `<svg width="100%" height="100%" viewBox="0 0 ${this.originalWidth} ${this.originalHeight}" xmlns="http://www.w3.org/2000/svg">`;

    clickAreas.forEach((area) => {
      let transform = "";
      if (area.x !== 0 || area.y !== 0) {
        transform += `translate(${area.x}, ${area.y}) `;
      }
      if (area.scale !== 1.0) {
        transform += `scale(${area.scale}) `;
      }

      svgContent += `<path id="${area.id}" d="${area.path}" fill="${area.fill}" fill-opacity="${area.fillOpacity}" stroke="${area.stroke}" stroke-width="2" cursor="pointer"`;
      if (transform) {
        svgContent += ` transform="${transform.trim()}"`;
      }
      svgContent += ` />`;
    });

    svgContent += "</svg>";
    svgElement.innerHTML = svgContent;

    clickAreas.forEach((area) => {
      const pathElement = svgElement.querySelector(`#${area.id}`);
      if (!pathElement) return;

      const targetLayerClass =
        area.targetLayer === "customize-character"
          ? "customize-character"
          : "details";
      const targetLayer = this.element.querySelector(
        ".chambers-layer." + targetLayerClass
      );

      if (targetLayer) {
        pathElement.addEventListener("mouseenter", () => {
          targetLayer.classList.add("highlighted");
          pathElement.style.opacity = "0.8";
        });

        pathElement.addEventListener("mouseleave", () => {
          targetLayer.classList.remove("highlighted");
          pathElement.style.opacity = "1";
        });
      }

      pathElement.addEventListener("click", () => {
        if (area.action === "showDetailsModal") {
          this.showDetailsModal();
        } else if (area.action === "openSidebar") {
          this.openSidebar();
        }
      });
    });

    this.hoverOverlayTarget.appendChild(svgElement);
  }

  updateHoverSVGPosition() {
    const svgElement = this.hoverOverlayTarget.querySelector(".hover-box");
    if (!svgElement) return;

    const scaleX = window.innerWidth / this.originalWidth;
    const scaleY = window.innerHeight / this.originalHeight;
    const baseScale = Math.max(scaleX, scaleY);

    const scaledWidth = this.originalWidth * baseScale;
    const scaledHeight = this.originalHeight * baseScale;

    const chambersOffsetX = (window.innerWidth - scaledWidth) / 2;
    const chambersOffsetY = (window.innerHeight - scaledHeight) / 2;

    svgElement.style.position = "absolute";
    svgElement.style.left = chambersOffsetX + "px";
    svgElement.style.top = chambersOffsetY + "px";
    svgElement.style.width = scaledWidth + "px";
    svgElement.style.height = scaledHeight + "px";
  }

  updateMeeplePosition() {
    if (!this.hasMeepleDisplayTarget || !this.hasMeepleContainerTarget) return;

    const scaleX = window.innerWidth / this.originalWidth;
    const scaleY = window.innerHeight / this.originalHeight;
    const baseScale = Math.max(scaleX, scaleY);

    const scaledWidth = this.originalWidth * baseScale;
    const scaledHeight = this.originalHeight * baseScale;

    const chambersOffsetX = (window.innerWidth - scaledWidth) / 2;
    const chambersOffsetY = (window.innerHeight - scaledHeight) / 2;

    const scaledMeepleX =
      this.meepleConfig.x * baseScale * this.meepleConfig.scale +
      chambersOffsetX;
    const scaledMeepleY =
      this.meepleConfig.y * baseScale * this.meepleConfig.scale +
      chambersOffsetY;
    const scaledMeepleWidth =
      this.meepleConfig.width * baseScale * this.meepleConfig.scale;
    const scaledMeepleHeight =
      this.meepleConfig.height * baseScale * this.meepleConfig.scale;

    this.meepleDisplayTarget.style.left = scaledMeepleX + "px";
    this.meepleDisplayTarget.style.top = scaledMeepleY + "px";

    this.meepleContainerTarget.style.width = scaledMeepleWidth + "px";
    this.meepleContainerTarget.style.height = scaledMeepleHeight + "px";

    this.renderMeepleDisplay();
  }

  initializeMeepleDisplay() {
    console.log("initializeMeepleDisplay called");
    console.log("MeepleDisplay available:", typeof window.MeepleDisplay);

    if (typeof window.MeepleDisplay === "undefined") {
      console.log("MeepleDisplay not loaded yet, retrying in 100ms");
      setTimeout(() => this.initializeMeepleDisplay(), 100);
      return;
    }

    this.renderMeepleDisplay();
  }

  renderMeepleDisplay() {
    if (!this.hasMeepleContainerTarget) return;
    if (typeof window.MeepleDisplay === "undefined") return;

    // Get currently equipped cosmetics from the UI state (live data)
    const equippedCosmetics = this.getEquippedCosmetics();
    const currentColor = this.getCurrentColor();
    const colorPaths = this.colorPathsValue || {};

    const userData = {
      meeple: {
        color: currentColor,
        imageSrc: colorPaths[currentColor] || this.meepleImageSrcValue,
        meeple_cosmetics: equippedCosmetics,
      },
    };

    const currentWidth =
      parseInt(this.meepleContainerTarget.style.width) || 200;
    const currentHeight =
      parseInt(this.meepleContainerTarget.style.height) || 240;

    console.log(
      "Rendering meeple with dimensions:",
      currentWidth,
      currentHeight
    );

    if (typeof window.renderUnifiedMeeple === "function") {
      const success = renderUnifiedMeeple(
        userData,
        this.meepleContainerTarget,
        null,
        null,
        currentWidth,
        currentHeight
      );
      if (success) {
        console.log("Meeple rendering complete using unified renderer");
      } else {
        console.log("Unified renderer failed, using direct MeepleDisplay");
        const meepleDisplay = new MeepleDisplay(
          userData,
          currentWidth,
          currentHeight
        );
        meepleDisplay.renderToHTML(this.meepleContainerTarget);
      }
    } else {
      const meepleDisplay = new MeepleDisplay(
        userData,
        currentWidth,
        currentHeight
      );
      meepleDisplay.renderToHTML(this.meepleContainerTarget);
      console.log("Meeple rendering complete using direct MeepleDisplay");
    }
  }

  getCurrentColor() {
    const activeColorOption = this.element.querySelector(
      ".color-option.active"
    );
    return activeColorOption
      ? activeColorOption.dataset.color
      : this.meepleColorValue;
  }

  getEquippedCosmetics() {
    const equippedCosmetics = [];
    const cosmeticDatabase = this.unlockedCosmeticsValue || {};

    this.element.querySelectorAll(".cosmetic-item.equipped").forEach((item) => {
      const cosmeticId = item.dataset.cosmeticId;
      const cosmeticData = cosmeticDatabase[cosmeticId];
      if (cosmeticData) {
        equippedCosmetics.push({
          equipped: true,
          cosmetic: cosmeticData,
        });
      }
    });

    const renderOrder = [
      "back",
      "hat",
      "eyes",
      "front",
      "neck",
      "feet",
      "cloak",
      "face",
      "left",
      "right",
    ];
    equippedCosmetics.sort((a, b) => {
      const aIndex =
        renderOrder.indexOf(a.cosmetic.type) !== -1
          ? renderOrder.indexOf(a.cosmetic.type)
          : 999;
      const bIndex =
        renderOrder.indexOf(b.cosmetic.type) !== -1
          ? renderOrder.indexOf(b.cosmetic.type)
          : 999;
      return aIndex - bIndex;
    });

    return equippedCosmetics;
  }

  openSidebar() {
    if (this.hasSidebarTarget) this.sidebarTarget.classList.add("open");
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("open");
    document.body.style.overflow = "hidden";
  }

  closeSidebar() {
    if (this.hasSidebarTarget) this.sidebarTarget.classList.remove("open");
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("open");
    document.body.style.overflow = "";
  }

  updateColor(event) {
    const color = event.currentTarget.dataset.color;
    if (!color) return;

    const colorOptions = this.element.querySelectorAll(".color-option");
    const originalColor = this.getCurrentColor();

    colorOptions.forEach((option) => {
      option.classList.toggle("active", option.dataset.color === color);
    });

    this.renderMeepleDisplay();

    const formData = new FormData();
    formData.append('meeple[color]', color);

    fetch('/chambers', {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
      },
      body: formData
    })
      .then((response) => {
        if (response.ok) {
          console.log("Successfully updated meeple color");
        } else {
          colorOptions.forEach((option) => {
            option.classList.toggle(
              "active",
              option.dataset.color === originalColor
            );
          });
          this.renderMeepleDisplay();
          console.error("Failed to update meeple color - reverted UI");
          this.showErrorMessage(
            "Failed to update meeple color. Please try again."
          );
        }
      })
      .catch((error) => {
        colorOptions.forEach((option) => {
          option.classList.toggle(
            "active",
            option.dataset.color === originalColor
          );
        });
        this.renderMeepleDisplay();
        console.error("Network error updating meeple color:", error);
        this.showErrorMessage(
          "Connection error. Please check your network and try again."
        );
      });
  }

  toggleCosmetic(event) {
    const cosmeticId = event.currentTarget.dataset.cosmeticId;
    const cosmeticType = event.currentTarget.dataset.cosmeticType;
    const item = event.currentTarget;

    const wasEquipped = item.classList.contains("equipped");

    this.element
      .querySelectorAll(`.cosmetic-item[data-cosmetic-type="${cosmeticType}"]`)
      .forEach((otherItem) => {
        otherItem.classList.remove("equipped");
      });

    if (!wasEquipped) {
      item.classList.add("equipped");
    }

    this.renderMeepleDisplay();

    const paramName = wasEquipped ? 'unequip_cosmetic_id' : 'equip_cosmetic_id';
    const formData = new FormData();
    formData.append(`meeple[${paramName}]`, cosmeticId);

    fetch('/chambers', {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
      },
      body: formData
    })
      .then((response) => {
        if (response.ok) {
          console.log("Successfully toggled cosmetic");
        } else {
          item.classList.toggle("equipped", wasEquipped);
          this.renderMeepleDisplay();
          console.error("Failed to toggle cosmetic - reverted UI");
          this.showErrorMessage("Failed to update cosmetic. Please try again.");
        }
      })
      .catch((error) => {
        item.classList.toggle("equipped", wasEquipped);
        this.renderMeepleDisplay();
        console.error("Network error toggling cosmetic:", error);
        this.showErrorMessage(
          "Connection error. Please check your network and try again."
        );
      });
  }

  showDetailsModal() {
    const address = this.addressValue;

    if (address && address.present) {
      let message = `<div style="text-align: left; font-size: 1.1rem; line-height: 1.6;">
        <div style="margin-bottom: 1rem;"><strong>Name:</strong> ${
          address.first_name
        } ${address.last_name}</div>
        <div style="margin-bottom: 1rem;"><strong>Birthday:</strong> ${
          address.birthday
        }</div>
        ${
          address.shipping_name
            ? `<div style="margin-bottom: 1rem;"><strong>Preferred Shipping Name:</strong> ${address.shipping_name}</div>`
            : ""
        }
        <div style="margin-bottom: 1rem;"><strong>Address:</strong><br>
          ${address.line_one}<br>
          ${address.line_two ? `${address.line_two}<br>` : ""}
          ${address.city}, ${address.state} ${address.postcode}<br>
          ${address.human_country}
        </div>
      </div>`;

      window.showModal("Your Details", "", [
        {
          text: "Edit Details",
          primary: true,
          action: () => {
            window.location.href = this.editChambersUrlValue;
          },
        },
        {
          text: "Logout",
          action: () => {
            this.logout();
          },
        },
        { text: "Close", action: () => {} },
      ]);

      const modalMessage = document.getElementById("modal-message");
      if (modalMessage) {
        modalMessage.innerHTML = message;
      }
    } else {
      window.showModal(
        "Your Details",
        "Complete your account setup to participate fully in Siege.",
        [
          {
            text: "Finish Setup",
            primary: true,
            action: () => {
              this.startAddressSetup();
            },
          },
          {
            text: "Logout",
            action: () => {
              this.logout();
            },
          },
          { text: "Close", action: () => {} },
        ]
      );
    }
  }

  startAddressSetup() {
    window.showModalAlert(
      "Starting identity verification... Please complete the verification in the popup window.",
      "Verification Required"
    );

    const authorizer = new SubmitAuthorizer();

    authorizer
      .authorize()
      .then((result) => {
        if (result.verified && result.identityData) {
          return fetch("/process_identity_and_address", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
                .content,
            },
            body: JSON.stringify({
              identity_data: result.identityData,
              idv_rec: result.idvRec,
            }),
          });
        } else {
          throw new Error("Identity verification not completed");
        }
      })
      .then((response) => response.json())
      .then((data) => {
        switch (data.status) {
          case "address_created":
            window.hideModal();
            this.showShippingNameModalForSetup();
            break;
          case "partial_data":
          case "missing_address":
            window.location.href = data.redirect_url;
            break;
          case "verified":
            window.location.reload();
            break;
          case "verification_failed":
          case "error":
            throw new Error(data.message || "Verification failed");
          default:
            throw new Error("Unknown response status");
        }
      })
      .catch((error) => {
        console.error("Verification error:", error);
        if (error.message === "Authorization cancelled by user") {
          window.showModalAlert(
            "Identity verification was cancelled.",
            "Verification Cancelled"
          );
        } else {
          window.showModalAlert(
            "Identity verification failed. Please try again or contact @Olive on slack.",
            "Error"
          );
        }
      });
  }

  showShippingNameModalForSetup() {
    const modal = document.getElementById("modal");
    const modalTitle = document.getElementById("modal-title");
    const modalMessage = document.getElementById("modal-message");
    const modalActions = document.getElementById("modal-actions");

    modalTitle.textContent = "Almost done!";
    modalMessage.innerHTML = "";
    modalActions.innerHTML = "";

    const explanationText = document.createElement("p");
    explanationText.textContent =
      "Your address has been set up automatically. You can optionally set a preferred shipping name if you want packages sent to a different name than what's on your ID.";
    explanationText.style.cssText =
      "font-size: 1rem; line-height: 1.5; margin-bottom: 1.5rem;";
    modalMessage.appendChild(explanationText);

    const fieldset = document.createElement("fieldset");
    fieldset.className = "fieldset";
    fieldset.style.cssText = "margin: 1.5rem 0;";

    const legend = document.createElement("legend");
    legend.className = "fieldset-legend";
    legend.textContent = "Preferred Shipping Name (Optional)";

    const underlineField = document.createElement("div");
    underlineField.className = "underline-field";

    const input = document.createElement("input");
    input.type = "text";
    input.className = "text-input";
    input.placeholder = "Leave blank to use your name from ID";

    underlineField.appendChild(input);
    fieldset.appendChild(legend);
    fieldset.appendChild(underlineField);
    modalMessage.appendChild(fieldset);

    const submitBtn = document.createElement("button");
    submitBtn.className = "submit-button submit-button--primary";
    submitBtn.textContent = "Continue";
    submitBtn.onclick = () => {
      const shippingName = input.value.trim();

      fetch("/update_shipping_name", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: JSON.stringify({ shipping_name: shippingName }),
      })
        .then((response) => response.json())
        .then((data) => {
          if (data.success) {
            window.location.reload();
          } else {
            throw new Error(data.error || "Failed to update shipping name");
          }
        })
        .catch((error) => {
          console.error("Error updating shipping name:", error);
          window.showModalAlert(
            "Failed to update shipping name. Please try again.",
            "Error"
          );
        });
    };

    const skipBtn = document.createElement("button");
    skipBtn.className = "submit-button";
    skipBtn.textContent = "Skip";
    skipBtn.style.cssText = "margin-left: 1rem;";
    skipBtn.onclick = () => {
      window.location.reload();
    };

    modalActions.appendChild(submitBtn);
    modalActions.appendChild(skipBtn);
    modal.classList.add("visible");
  }

  logout() {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "/logout";

    const methodInput = document.createElement("input");
    methodInput.type = "hidden";
    methodInput.name = "_method";
    methodInput.value = "delete";
    form.appendChild(methodInput);

    const csrfInput = document.createElement("input");
    csrfInput.type = "hidden";
    csrfInput.name = "authenticity_token";
    csrfInput.value = document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content");
    form.appendChild(csrfInput);

    document.body.appendChild(form);
    form.submit();
  }

  showErrorMessage(message) {
    if (typeof window.showModalAlert === "function") {
      window.showModalAlert(message, "Error");
    } else {
      console.error(message);
    }
  }

  cleanup() {
    if (this.cloudTimeout) {
      clearTimeout(this.cloudTimeout);
      this.cloudTimeout = null;
    }

    window.removeEventListener("resize", this.resizeHandler);
  }
}
