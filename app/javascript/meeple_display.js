class MeepleDisplay {
  constructor(user, boxSize = 80, visualSize = 100) {
    this.user = user;
    this.boxSize = boxSize;
    this.visualSize = visualSize;
    this.offset = (visualSize - boxSize) / 2;
  }

  // Get meeple image source
  getMeepleImageSrc() {
    // Use the imageSrc if provided, otherwise construct the path
    return (
      this.user.meeple.imageSrc ||
      `/assets/meeple/meeple-${this.user.meeple.color}.png`
    );
  }

  // Get cosmetic image source
  getCosmeticImageSrc(cosmetic) {
    if (cosmetic.image && cosmetic.image.attached) {
      return cosmetic.image.url;
    }
    return null;
  }

  // Get equipped cosmetics sorted by render order
  getEquippedCosmetics() {
    // This assumes you have a way to get equipped cosmetics
    // You might need to adjust this based on your actual data structure
    if (this.user.meeple && this.user.meeple.meeple_cosmetics) {
      const cosmetics = this.user.meeple.meeple_cosmetics
        .filter((mc) => mc.equipped)
        .map((mc) => mc.cosmetic);
      
      // Sort by proper render order: Back, Hat, Eyes, Front, Neck, Feet, Cloak, Face, Left, Right
      const renderOrder = ['back', 'hat', 'eyes', 'front', 'neck', 'feet', 'cloak', 'face', 'left', 'right'];
      
      return cosmetics.sort((a, b) => {
        const aIndex = renderOrder.indexOf(a.type) !== -1 ? renderOrder.indexOf(a.type) : 999;
        const bIndex = renderOrder.indexOf(b.type) !== -1 ? renderOrder.indexOf(b.type) : 999;
        return aIndex - bIndex;
      });
    }
    return [];
  }

  // For Canvas rendering
  drawToCanvas(ctx, x, y) {
    const drawX = x - this.offset;
    const drawY = y - this.offset;

    // Draw meeple base
    const meepleImage = this.getMeepleImage();
    if (meepleImage && meepleImage.complete) {
      ctx.drawImage(
        meepleImage,
        drawX,
        drawY,
        this.visualSize,
        this.visualSize
      );
    }

    // Draw cosmetics
    this.getEquippedCosmetics().forEach((cosmetic) => {
      const cosmeticImage = this.getCosmeticImage(cosmetic);
      if (cosmeticImage && cosmeticImage.complete) {
        ctx.drawImage(
          cosmeticImage,
          drawX,
          drawY,
          this.visualSize,
          this.visualSize
        );
      }
    });
  }

  // Get meeple image for canvas
  getMeepleImage() {
    const imagePath = this.getMeepleImageSrc();
    // This assumes you have a global meepleImages object or similar
    return window.meepleImages ? window.meepleImages[imagePath] : null;
  }

  // Get cosmetic image for canvas
  getCosmeticImage(cosmetic) {
    const imageSrc = this.getCosmeticImageSrc(cosmetic);
    if (!imageSrc) return null;
    return window.meepleImages ? window.meepleImages[imageSrc] : null;
  }

  // For HTML rendering
  renderToHTML(container) {
    container.style.position = "relative";
    container.style.width = `${this.boxSize}px`;
    container.style.height = `${this.boxSize}px`;
    container.style.overflow = "visible";

    // Clear existing content
    container.innerHTML = "";

    // Add meeple base
    const meepleImg = document.createElement("img");
    meepleImg.src = this.getMeepleImageSrc();
    meepleImg.alt = `${this.user.meeple.color} meeple`;
    meepleImg.style.position = "absolute";
    meepleImg.style.top = `-${this.offset}px`;
    meepleImg.style.left = `-${this.offset}px`;
    meepleImg.style.width = `${this.visualSize}px`;
    meepleImg.style.height = `${this.visualSize}px`;
    meepleImg.style.zIndex = "1";
    meepleImg.style.objectFit = "contain";
    container.appendChild(meepleImg);

    // Add cosmetics
    this.getEquippedCosmetics().forEach((cosmetic, index) => {
      const cosmeticImg = document.createElement("img");
      cosmeticImg.src = this.getCosmeticImageSrc(cosmetic);
      cosmeticImg.alt = cosmetic.name;
      cosmeticImg.style.position = "absolute";
      cosmeticImg.style.top = `-${this.offset}px`;
      cosmeticImg.style.left = `-${this.offset}px`;
      cosmeticImg.style.width = `${this.visualSize}px`;
      cosmeticImg.style.height = `${this.visualSize}px`;
      cosmeticImg.style.zIndex = `${2 + index}`;
      cosmeticImg.style.objectFit = "contain";
      container.appendChild(cosmeticImg);
    });
  }

  // Static method to create from user data
  static fromUser(user, boxSize = 80, visualSize = 100) {
    return new MeepleDisplay(user, boxSize, visualSize);
  }
}

// Unified meeple rendering function that works with both HTML and Canvas
window.renderUnifiedMeeple = function(userData, containerOrCtx, x, y, boxSize = 80, visualSize = 100) {
  console.log('renderUnifiedMeeple called with:', { userData, containerOrCtx, x, y, boxSize, visualSize });
  
  if (!userData || !userData.meeple) {
    console.error('Invalid userData provided to renderUnifiedMeeple');
    return false;
  }

  try {
    const meepleDisplay = new MeepleDisplay(userData, boxSize, visualSize);
    
    // Check if it's a canvas context (has drawImage method) or HTML container
    if (containerOrCtx && typeof containerOrCtx.drawImage === 'function') {
      // Canvas rendering
      console.log('Using canvas rendering');
      meepleDisplay.drawToCanvas(containerOrCtx, x, y);
    } else if (containerOrCtx && containerOrCtx.nodeType) {
      // HTML container rendering
      console.log('Using HTML rendering');
      meepleDisplay.renderToHTML(containerOrCtx);
    } else {
      console.error('Invalid container or context provided to renderUnifiedMeeple');
      return false;
    }
    
    console.log('Successfully rendered unified meeple');
    return true;
  } catch (error) {
    console.error('Error in renderUnifiedMeeple:', error);
    return false;
  }
};

// Make it globally available
window.MeepleDisplay = MeepleDisplay;
