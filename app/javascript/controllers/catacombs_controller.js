import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "hoverOverlay",
    "glyphDisplay",
    "mystereepleDialogue",
    "mystereepleText",
    "mystereepleButtons",
    "bettingInterface",
    "bettingTitle",
    "bettingModeToggle",
    "userCoinsDisplay",
    "personalBettingContent",
    "globalBettingContent",
    "shopInterface",
    "shopUserCoinsDisplay",
    "shopItemsGrid",
    "shopItemModal",
  ];

  static values = {
    mystereepleVisible: Boolean,
    userIsOut: Boolean,
    hasBetting: Boolean,
    hasShop: Boolean,
    hasSecret: Boolean,
    currentRunes: String,
    personalBet: Boolean,
    globalBet: Boolean,
    bettingEnabled: Boolean,
    isBettingDay: Boolean,
    availableWindows: Array,
  };

  connect() {
    console.log("Catacombs controller connected");

    this.originalWidth = 3392;
    this.originalHeight = 2358;
    this.glyphConfig = {
      x: 1560,
      y: 1100,
      fontSize: 50,
    };

    this.glyphBuffer = this.currentRunesValue ?? "";
    this.glyphOffsets = [];
    this.allowedChars = /^[a-zA-Z0-9!@%&()"';:,.+\-=?]$/;

    this.typingInProgress = false;
    this.currentTypingTimeout = null;

    this.selectedBetHours = null;
    this.selectedBetMultiplier = null;
    this.betAmount = 25;
    this.globalBetAmount = 25;
    this.hoursPrediction = 1000;
    this.lastWeekHours = 0;
    this.globalMultiplier = 1.5;
    this.bettingMode = "personal";
    this.userCoins = 0;
    this.currentWindowIndex = 0;

    this.resizeHandler = () => {
      this.updateHoverSVGPosition();
      this.updateGlyphPosition();
    };

    this.keypressHandler = this.handleKeypress.bind(this);
    this.keydownHandler = this.handleKeydown.bind(this);

    this.initialize();
  }

  disconnect() {
    console.log("Catacombs controller disconnected");
    this.cleanup();
  }

  initialize() {
    console.log("Catacombs: Initializing...");

    try {
      this.setupHoverSystem();
      this.setupGlyphSystem();
      this.registerWithSiegeApp();
      return true;
    } catch (error) {
      console.error("Catacombs: Initialization failed:", error);
      return false;
    }
  }

  registerWithSiegeApp() {
    if (window.SiegeApp && typeof window.SiegeBaseManager !== "undefined") {
      console.log("Registering CatacombsManager with SiegeApp");
      const manager = {
        init: () => {
          /* Already initialized */
        },
        resize: () => {
          this.updateHoverSVGPosition();
          this.updateGlyphPosition();
        },
        cleanup: () => this.cleanup(),
      };
      window.SiegeApp.registerManager("catacombs", manager);
    } else {
      setTimeout(() => this.registerWithSiegeApp(), 50);
    }
  }

  setupHoverSystem() {
    if (!this.hasHoverOverlayTarget) return;

    this.hoverOverlayTarget.innerHTML = "";
    this.createHoverSVG();
    this.updateHoverSVGPosition();

    window.addEventListener("resize", this.resizeHandler);
  }

  setupGlyphSystem() {
    if (!this.hasGlyphDisplayTarget) return;

    for (let i = 0; i < this.glyphBuffer.length; i++) {
      const position = (i - 2) / 5;
      const curveOffset = -5 * (1 - 4 * position * position);
      const randomOffset = (Math.random() - 0.5) * 4;
      this.glyphOffsets.push(curveOffset + randomOffset);
    }

    if (this.glyphBuffer.length > 0) {
      this.updateGlyphDisplay();
    }

    this.updateGlyphPosition();

    document.addEventListener("keypress", this.keypressHandler);
    document.addEventListener("keydown", this.keydownHandler);
  }

  createHoverSVG() {
    const svgElement = document.createElement("div");
    svgElement.className = "hover-box";

    const clickAreas = [];

    if (this.mystereepleVisibleValue) {
      clickAreas.push({
        id: "mystereeple",
        path: `M177 754H109L91 687.5L148.5 516.5L68.5 499L1 466L17.5 426.5L68.5 368.5L152 321L148.5 265.5L160.5 252V205.5L176 158.5L112.5 131.5L100.5 112.5L124.5 87L198 82L234.5 1L338.5 19.5L347.5 40L363.5 19.5L470 32L474 121.5L539.5 150.5V180.5L516 193.5L451 205.5L459 269L430.5 321L486 351L539.5 404L559 438L550 473.5L525 486L436 512.5L413.5 648.5L418.5 717.5L360 773.5L293 712L221 704L177 754Z`,
        fill: "#E40000",
        fillOpacity: "0",
        stroke: "",
        x: 2050,
        y: 1360,
        scale: 1,
        targetLayer: "mystereeple",
      });
    }

    let svgContent = `<svg width="100%" height="100%" viewBox="0 0 ${this.originalWidth} ${this.originalHeight}" xmlns="http://www.w3.org/2000/svg">`;

    clickAreas.forEach((area) => {
      if (!area.path) return;

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
      if (!area.path) return;

      const pathElement = svgElement.querySelector(`#${area.id}`);
      if (!pathElement) return;

      const targetLayer = document.querySelector(
        ".catacombs-layer." + area.targetLayer
      );

      pathElement.addEventListener("mouseenter", () => {
        if (targetLayer) targetLayer.classList.add("highlighted");
        pathElement.style.opacity = "0.8";
      });

      pathElement.addEventListener("mouseleave", () => {
        if (targetLayer) targetLayer.classList.remove("highlighted");
        pathElement.style.opacity = "1";
      });

      pathElement.addEventListener("click", () => {
        this.showMystereepleDialogue();
      });
    });

    this.hoverOverlayTarget.appendChild(svgElement);
  }

  updateHoverSVGPosition() {
    const svgElement = this.hoverOverlayTarget?.querySelector(".hover-box");
    if (!svgElement) return;

    const scaleX = window.innerWidth / this.originalWidth;
    const scaleY = window.innerHeight / this.originalHeight;
    const baseScale = Math.max(scaleX, scaleY);

    const scaledWidth = this.originalWidth * baseScale;
    const scaledHeight = this.originalHeight * baseScale;

    const catacombsOffsetX = (window.innerWidth - scaledWidth) / 2;
    const catacombsOffsetY = (window.innerHeight - scaledHeight) / 2;

    svgElement.style.position = "absolute";
    svgElement.style.left = catacombsOffsetX + "px";
    svgElement.style.top = catacombsOffsetY + "px";
    svgElement.style.width = scaledWidth + "px";
    svgElement.style.height = scaledHeight + "px";
  }

  updateGlyphPosition() {
    if (!this.hasGlyphDisplayTarget) return;

    const scaleX = window.innerWidth / this.originalWidth;
    const scaleY = window.innerHeight / this.originalHeight;
    const baseScale = Math.max(scaleX, scaleY);

    const scaledWidth = this.originalWidth * baseScale;
    const scaledHeight = this.originalHeight * baseScale;

    const catacombsOffsetX = (window.innerWidth - scaledWidth) / 2;
    const catacombsOffsetY = (window.innerHeight - scaledHeight) / 2;

    const scaledGlyphX = this.glyphConfig.x * baseScale + catacombsOffsetX;
    const scaledGlyphY = this.glyphConfig.y * baseScale + catacombsOffsetY;
    const scaledFontSize = this.glyphConfig.fontSize * baseScale;

    this.glyphDisplayTarget.style.left = scaledGlyphX + "px";
    this.glyphDisplayTarget.style.top = scaledGlyphY + "px";
    this.glyphDisplayTarget.style.fontSize = scaledFontSize + "px";
    this.glyphDisplayTarget.style.transform = "rotate(3deg)";
    this.glyphDisplayTarget.style.transformOrigin = "left top";
  }

  updateGlyphDisplay() {
    if (!this.hasGlyphDisplayTarget) return;

    this.glyphDisplayTarget.innerHTML = "";

    for (let i = 0; i < this.glyphBuffer.length; i++) {
      const char = this.glyphBuffer[i];
      const span = document.createElement("span");
      span.className = "glyph-char";
      span.textContent = char;
      span.style.transform = `translateY(${this.glyphOffsets[i]}px)`;
      this.glyphDisplayTarget.appendChild(span);
    }
  }

  handleKeypress(e) {
    const char = e.key;

    if (!this.allowedChars.test(char)) return;
    if (this.glyphBuffer.length >= 5) return;

    const upperChar = char.toUpperCase();
    const i = this.glyphBuffer.length;
    const position = (i - 2) / 5;
    const curveOffset = -5 * (1 - 4 * position * position);
    const randomOffset = (Math.random() - 0.5) * 4;
    const totalOffset = curveOffset + randomOffset;

    this.glyphOffsets.push(totalOffset);
    this.glyphBuffer += upperChar;

    this.updateGlyphDisplay();
    this.logRunes(this.glyphBuffer);
  }

  handleKeydown(e) {
    if (e.key === "Enter" && this.glyphBuffer.length > 0) {
      e.preventDefault();
      this.logRunes(this.glyphBuffer);
    }

    if (e.key === "Backspace" && this.glyphBuffer.length > 0) {
      e.preventDefault();
      this.glyphBuffer = this.glyphBuffer.slice(0, -1);
      this.glyphOffsets = this.glyphOffsets.slice(0, -1);
      this.updateGlyphDisplay();
      this.logRunes(this.glyphBuffer);
    }
  }

  async logRunes(runes) {
    try {
      await fetch("/catacombs/log_runes", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: JSON.stringify({ runes: runes }),
      });
    } catch (error) {
      console.error("Error logging runes:", error);
    }
  }

  async typeText(element, text, speed = 50) {
    return new Promise((resolve, reject) => {
      if (this.currentTypingTimeout) {
        clearTimeout(this.currentTypingTimeout);
      }

      element.textContent = "";
      let index = 0;
      this.typingInProgress = true;

      const type = () => {
        if (!this.typingInProgress) {
          reject("cancelled");
          return;
        }

        if (index < text.length) {
          element.textContent += text.charAt(index);
          index++;
          this.currentTypingTimeout = setTimeout(type, speed);
        } else {
          this.typingInProgress = false;
          this.currentTypingTimeout = null;
          resolve();
        }
      };

      type();
    });
  }

  async showMystereepleDialogue() {
    if (
      !this.hasMystereepleDialogueTarget ||
      !this.hasMystereepleTextTarget ||
      !this.hasMystereepleButtonsTarget
    )
      return;

    if (this.typingInProgress) {
      this.typingInProgress = false;
      if (this.currentTypingTimeout) {
        clearTimeout(this.currentTypingTimeout);
        this.currentTypingTimeout = null;
      }
    }

    this.mystereepleDialogueTarget.classList.add("visible");
    this.mystereepleButtonsTarget.classList.remove("visible");

    if (this.userIsOutValue) {
      try {
        await this.typeText(
          this.mystereepleTextTarget,
          "Sorry, but I cannot talk to you if you aren't still in the siege..."
        );
        setTimeout(() => this.closeMystereepleDialogue(), 3000);
      } catch (e) {
        // Typing was cancelled
      }
      return;
    }

    if (!this.mystereepleVisibleValue) {
      try {
        await this.typeText(
          this.mystereepleTextTarget,
          "Check back here later, I'll have something for you in a couple days :)"
        );
        setTimeout(() => this.closeMystereepleDialogue(), 3000);
      } catch (e) {
        // Typing was cancelled
      }
      return;
    }

    this.currentWindowIndex = 0;
    this.mystereepleButtonsTarget.innerHTML = "";

    try {
      await this.typeText(
        this.mystereepleTextTarget,
        "What are you looking for?"
      );

      if (this.availableWindowsValue.length > 0) {
        const firstWindow = this.availableWindowsValue[0];
        const buttonText = this.getWindowButtonText(firstWindow.type);

        const btn1 = document.createElement("button");
        btn1.className = "mystereeple-dialogue-button";
        btn1.textContent = buttonText;
        btn1.onclick = () => this.handleWindowAction(firstWindow.type);
        this.mystereepleButtonsTarget.appendChild(btn1);

        const btn2 = document.createElement("button");
        btn2.className = "mystereeple-dialogue-button";
        btn2.textContent = "Do you have anything else?";
        btn2.onclick = () => this.handleAnythingElse();
        this.mystereepleButtonsTarget.appendChild(btn2);
      }

      this.mystereepleButtonsTarget.classList.add("visible");
    } catch (e) {
      // Typing was cancelled
    }
  }

  closeMystereepleDialogue() {
    this.typingInProgress = false;
    if (this.hasMystereepleDialogueTarget) {
      this.mystereepleDialogueTarget.classList.remove("visible");
    }
    if (this.hasMystereepleButtonsTarget) {
      this.mystereepleButtonsTarget.classList.remove("visible");
    }
  }

  getWindowButtonText(windowType) {
    switch (windowType) {
      case "betting":
        return "Place a bet";
      case "shop":
        return "See the items";
      case "secret":
        return "Yes";
      default:
        return "View";
    }
  }

  getWindowQuestion(windowType) {
    switch (windowType) {
      case "betting":
        return "Would you like to place a bet?";
      case "shop":
        return "Would you like some items?";
      case "secret":
        return "You want to know a secret?";
      default:
        return "Interested?";
    }
  }

  handleWindowAction(windowType) {
    switch (windowType) {
      case "betting":
        this.handlePlaceBet();
        break;
      case "shop":
        this.handleSeeItems();
        break;
      case "secret":
        this.handleSecret();
        break;
    }
  }

  async handleAnythingElse() {
    this.currentWindowIndex++;

    this.mystereepleButtonsTarget.innerHTML = "";
    this.mystereepleButtonsTarget.classList.remove("visible");

    if (this.currentWindowIndex < this.availableWindowsValue.length) {
      const window = this.availableWindowsValue[this.currentWindowIndex];
      const question = this.getWindowQuestion(window.type);

      try {
        await this.typeText(this.mystereepleTextTarget, question);

        const btn1 = document.createElement("button");
        btn1.className = "mystereeple-dialogue-button";
        btn1.textContent = "Yes";
        btn1.onclick = () => this.handleWindowAction(window.type);
        this.mystereepleButtonsTarget.appendChild(btn1);

        const btn2 = document.createElement("button");
        btn2.className = "mystereeple-dialogue-button";
        btn2.textContent = "Do you have anything else?";
        btn2.onclick = () => this.handleAnythingElse();
        this.mystereepleButtonsTarget.appendChild(btn2);

        this.mystereepleButtonsTarget.classList.add("visible");
      } catch (e) {
        // Typing was cancelled
      }
    } else {
      try {
        await this.typeText(
          this.mystereepleTextTarget,
          "The only other thing is this wall behind me... I wonder what's behind it..."
        );
        setTimeout(() => this.closeMystereepleDialogue(), 3000);
      } catch (e) {
        // Typing was cancelled
      }
    }
  }

  async handleSecret() {
    this.mystereepleButtonsTarget.innerHTML = "";
    this.mystereepleButtonsTarget.classList.remove("visible");

    try {
      await this.typeText(
        this.mystereepleTextTarget,
        "I hear that if you include a jumpscare in your next project, it might help you out on a spooky halloween night..."
      );

      const btn1 = document.createElement("button");
      btn1.className = "mystereeple-dialogue-button";
      btn1.textContent = "Got it!";
      btn1.onclick = () => this.closeMystereepleDialogue();
      this.mystereepleButtonsTarget.appendChild(btn1);

      const btn2 = document.createElement("button");
      btn2.className = "mystereeple-dialogue-button";
      btn2.textContent = "Wait... what?";
      btn2.onclick = async () => {
        this.mystereepleButtonsTarget.innerHTML = "";
        this.mystereepleButtonsTarget.classList.remove("visible");

        try {
          await this.typeText(
            this.mystereepleTextTarget,
            "Hmmm... well yeah I don't know much... all I know is that there were talks of a big party this Saturday... might be good to have a jumpscare by then... but you didn't hear it from me..."
          );

          const btn3 = document.createElement("button");
          btn3.className = "mystereeple-dialogue-button";
          btn3.textContent = "Okay...";
          btn3.onclick = () => this.closeMystereepleDialogue();
          this.mystereepleButtonsTarget.appendChild(btn3);

          this.mystereepleButtonsTarget.classList.add("visible");
        } catch (e) {
          // Typing was cancelled
        }
      };
      this.mystereepleButtonsTarget.appendChild(btn2);

      this.mystereepleButtonsTarget.classList.add("visible");
    } catch (e) {
      // Typing was cancelled
    }
  }

  async handlePlaceBet() {
    if (!this.hasBettingInterfaceTarget) return;

    this.closeMystereepleDialogue();
    this.bettingInterfaceTarget.classList.add("visible");

    await this.loadUserCoins();

    if (this.lastWeekHours === 0 && this.bettingMode === "global") {
      await this.fetchLastWeekHours();
    }
  }

  async handleSeeItems() {
    if (!this.hasShopInterfaceTarget) return;

    this.closeMystereepleDialogue();
    this.shopInterfaceTarget.classList.add("visible");
    this.loadShopItems();
  }

  async loadUserCoins() {
    try {
      const response = await fetch("/market/user_coins", {
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
      });
      const data = await response.json();
      this.userCoins = data.coins || 0;
      if (this.hasUserCoinsDisplayTarget) {
        this.userCoinsDisplayTarget.textContent = this.userCoins;
      }
      this.updateBetButtonState();
    } catch (error) {
      console.error("Failed to load user coins:", error);
      this.userCoins = 0;
    }
  }

  async loadShopItems() {
    if (!this.hasShopItemsGridTarget) return;

    try {
      const response = await fetch("/catacombs/shop_items");
      const data = await response.json();

      this.userCoins = data.user_coins || 0;
      if (this.hasShopUserCoinsDisplayTarget) {
        this.shopUserCoinsDisplayTarget.textContent = this.userCoins;
      }

      this.shopItemsGridTarget.innerHTML = "";

      if (data.items.length === 0) {
        this.shopItemsGridTarget.innerHTML =
          '<p style="text-align: center; grid-column: 1/-1;">No items available</p>';
        return;
      }

      window.catacombsShopItems = data.items;

      data.items.forEach((item) => {
        const card = document.createElement("div");
        card.className = "shop-item-card";
        const canPurchase = item.remaining > 0 && item.cost <= this.userCoins;

        if (!canPurchase) {
          card.classList.add("disabled");
        }

        card.onclick = () => this.showItemModal(item, canPurchase);

        card.innerHTML = `
          ${
            item.image_url
              ? `<img src="${this.escapeHtml(
                  item.image_url
                )}" class="shop-item-image" alt="${this.escapeHtml(
                  item.name
                )}">`
              : ""
          }
          <div class="shop-item-name">${this.escapeHtml(item.name)}</div>
          <div class="shop-item-cost">${this.escapeHtml(
            String(item.cost)
          )} coins</div>
          <div class="shop-item-stock">${this.escapeHtml(
            String(item.remaining)
          )} left</div>
        `;

        this.shopItemsGridTarget.appendChild(card);
      });
    } catch (error) {
      console.error("Error loading shop items:", error);
      this.shopItemsGridTarget.innerHTML =
        '<p style="text-align: center; grid-column: 1/-1;">Failed to load items</p>';
    }
  }

  showItemModal(item, canPurchase) {
    if (!this.hasShopItemModalTarget) return;

    const content = this.shopItemModalTarget.querySelector(
      "#shop-modal-content"
    );
    if (!content) return;

    let purchaseButton = "";
    if (canPurchase) {
      purchaseButton = `<button class="betting-button" data-action="click->catacombs#purchaseShopItemFromModal" data-item-id="${
        item.id
      }" data-item-cost="${item.cost}" data-item-name="${this.escapeHtml(
        item.name
      )}">Purchase for ${this.escapeHtml(String(item.cost))} coins</button>`;
    } else if (item.remaining <= 0) {
      purchaseButton = `<button class="betting-button" disabled>Out of Stock</button>`;
    } else {
      purchaseButton = `<button class="betting-button" disabled>Need ${this.escapeHtml(
        String(item.cost - this.userCoins)
      )} more coins</button>`;
    }

    content.innerHTML = `
      ${
        item.image_url
          ? `<img src="${this.escapeHtml(
              item.image_url
            )}" class="shop-item-modal-image" alt="${this.escapeHtml(
              item.name
            )}">`
          : ""
      }
      <h2 class="shop-item-modal-title">${this.escapeHtml(item.name)}</h2>
      <div class="shop-item-modal-description">${this.escapeHtml(
        item.description || "No description available"
      )}</div>
      <div class="shop-item-modal-price">${this.escapeHtml(
        String(item.cost)
      )} coins</div>
      <div class="shop-item-modal-stock">${this.escapeHtml(
        String(item.remaining)
      )} left</div>
      <div class="shop-modal-actions">
        ${purchaseButton}
        <button class="betting-button" data-action="click->catacombs#closeItemModal">Close</button>
      </div>
    `;

    this.shopItemModalTarget.classList.add("visible");
  }

  closeItemModal() {
    if (this.hasShopItemModalTarget) {
      this.shopItemModalTarget.classList.remove("visible");
    }
  }

  async purchaseShopItemFromModal(event) {
    const button = event.currentTarget;
    const itemId = parseInt(button.dataset.itemId);
    const cost = parseInt(button.dataset.itemCost);
    const name = button.dataset.itemName;

    await this.purchaseShopItem(itemId, cost, name);
  }

  async purchaseShopItem(itemId, cost, name) {
    if (cost > this.userCoins) {
      this.showModalAlert("Not enough coins!", "Error");
      return;
    }

    const content = this.shopItemModalTarget.querySelector(
      "#shop-modal-content"
    );
    content.innerHTML = `
      <h2 class="shop-item-modal-title">Processing Purchase...</h2>
      <p style="text-align: center; color: #402b20;">Please wait...</p>
    `;

    try {
      const response = await fetch("/catacombs/purchase_shop_item", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: JSON.stringify({ item_id: itemId }),
      });

      const data = await response.json();

      if (data.success) {
        this.userCoins = data.new_balance;
        if (this.hasShopUserCoinsDisplayTarget) {
          this.shopUserCoinsDisplayTarget.textContent = this.userCoins;
        }
        if (this.hasUserCoinsDisplayTarget) {
          this.userCoinsDisplayTarget.textContent = this.userCoins;
        }

        content.innerHTML = `
          <h2 class="shop-item-modal-title">Purchase Complete!</h2>
          <p style="text-align: center; color: #402b20; margin-bottom: 2rem;">You purchased ${this.escapeHtml(
            name
          )}</p>
          <div class="shop-modal-actions">
            <button class="betting-button" data-action="click->catacombs#closeItemModalAndReload">Close</button>
          </div>
        `;
      } else {
        this.showModalAlert(data.message, "Error");
        this.shopItemModalTarget.classList.remove("visible");
      }
    } catch (error) {
      console.error("Error purchasing item:", error);
      this.showModalAlert("Failed to purchase item", "Error");
      this.shopItemModalTarget.classList.remove("visible");
    }
  }

  closeItemModalAndReload() {
    this.closeItemModal();
    this.loadShopItems();
  }

  closeShopInterface() {
    if (this.hasShopInterfaceTarget) {
      this.shopInterfaceTarget.classList.remove("visible");
    }
  }

  updateBetButtonState() {
    const personalButton = document.getElementById("submit-bet-button");
    const globalButton = document.getElementById("submit-global-bet-button");

    if (personalButton && this.bettingMode === "personal") {
      personalButton.disabled =
        !this.selectedBetHours || this.betAmount > this.userCoins;
    }
    if (globalButton && this.bettingMode === "global") {
      globalButton.disabled = this.globalBetAmount > this.userCoins;
    }
  }

  async fetchLastWeekHours() {
    try {
      const response = await fetch("/catacombs/last_week_hours");
      const data = await response.json();
      this.lastWeekHours = data.hours;
      const element = document.getElementById("last-week-hours");
      if (element) {
        element.textContent = this.lastWeekHours;
      }
      this.updateGlobalMultiplier();
    } catch (error) {
      console.error("Error fetching last week hours:", error);
      const element = document.getElementById("last-week-hours");
      if (element) {
        element.textContent = "Error";
      }
    }
  }

  updateGlobalMultiplier() {
    if (this.lastWeekHours === 0) {
      this.globalMultiplier = 1.5;
    } else {
      const percentage = this.hoursPrediction / this.lastWeekHours;

      if (percentage < 0.8) {
        this.globalMultiplier = 1.0;
      } else if (percentage < 1.0) {
        const t = (percentage - 0.8) / 0.2;
        this.globalMultiplier = 1.0 + 1.0 * (t * t);
      } else if (percentage < 1.05) {
        const t = (percentage - 1.0) / 0.05;
        this.globalMultiplier = 2.0 + 0.5 * (t * t);
      } else {
        this.globalMultiplier =
          2.5 + 0.5 * Math.pow((percentage - 1.05) / 0.05, 2);
      }
    }

    const element = document.getElementById("global-multiplier-display");
    if (element) {
      element.textContent = this.globalMultiplier.toFixed(2) + "x";
    }
    this.updateGlobalPayout();
  }

  updateGlobalPayout() {
    const payout = Math.floor(this.globalBetAmount * this.globalMultiplier);
    const element = document.getElementById("global-payout-display");
    if (element) {
      element.textContent = payout;
    }
  }

  showModalAlert(message, title) {
    alert(`${title}: ${message}`);
  }

  escapeHtml(str) {
    if (!str) return "";
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  cleanup() {
    if (this.currentTypingTimeout) {
      clearTimeout(this.currentTypingTimeout);
      this.currentTypingTimeout = null;
    }

    window.removeEventListener("resize", this.resizeHandler);
    document.removeEventListener("keypress", this.keypressHandler);
    document.removeEventListener("keydown", this.keydownHandler);
  }
}
