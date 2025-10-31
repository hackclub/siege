import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "marketDialogue",
    "shopInterface",
    "shopItemsGrid",
    "userCoins",
    "techTreeCoins",
    "shopItemModal",
    "modalItemImageContainer",
    "modalItemTitle",
    "modalItemDescription",
    "modalItemPrice",
    "modalItemStock",
    "modalBuyButton",
    "techTreeInterface",
    "techTreeViewport",
    "techTreeContainer",
    "techTreeNodes",
    "techTreeEdges",
    "initialSelectionModal",
    "initialSelectionTitle",
    "initialOptions",
    "switchDeviceBtn",
    "switchDeviceText",
    "grantTotalDisplay",
    "grantTotalAmount",
    "techNodeModal",
    "techNodeModalTitle",
    "techNodeModalStatus",
    "techNodeModalDescription",
    "techNodeModalPrice",
    "techNodeModalInfo",
    "techNodeBuyButton",
    "statusModal",
    "statusModalText",
    "statusModalButton"
  ]

  static values = {
    userInSupportedRegion: Boolean,
    purchasedOneTimeItems: Array,
    purchasableCosmetics: Array,
    purchasablePhysicalItems: Array,
    coinAsset: String,
    meepleAsset: String
  }

  connect() {
    console.log("Market controller connected")
    
    this.initializeState()
    this.initializeShopData()
    this.loadInitialData()
    this.setupTechTreeListeners()
  }

  disconnect() {
    console.log("Market controller disconnected")
    this.cleanup()
  }

  initializeState() {
    // Shop state
    this.userCoins = 0
    this.mercenaryPrice = 35
    this.mercenaryCount = 0
    this.timeTravellingMercenaryQuantity = 0
    this.timeTravellingMercenaryInventory = 0
    this.currentItem = null
    this.shopItems = {}

    // Tech tree state
    this.techTreeData = null
    this.viewingDeviceType = null
    this.userMainDeviceBranchId = null
    this.currentBranchId = null
    this.techTreePurchases = {}
    this.techTreeZoom = 1
    this.techTreePan = { x: 0, y: 0 }
    this.isPanning = false
    this.panStart = { x: 0, y: 0 }
    this.currentTechNode = null
    this.checkInterval = null

    // Constants
    this.BASE_DISTANCE = 200
    this.DIRECTION_MULTIPLIERS = {
      'left': [-1.5, 0],
      'left1': [-1.5, -1],
      'left2': [-1.5, -2],
      'left3': [-1.5, -3],
      'left-1': [-1.5, 1],
      'left-2': [-1.5, 2],
      'right': [1.5, 0],
      'right1': [1.5, -1],
      'right2': [1.5, -2],
      'right3': [1.5, -3],
      'right-1': [1.5, 1],
      'right-2': [1.5, 2],
      'rightright1': [3, -1],
      'rightright2': [3, -2],
      'leftleft1': [-3, -1],
      'up': [0, -1.5],
      'up2': [0, -3],
      'up3': [0, -4.5],
      'up4': [0, -6],
      'up5': [0, -7.5],
      'down': [0, 1.5],
      'down2': [0, 3],
      'down3': [0, 4.5]
    }
  }

  initializeShopData() {
    const allShopItems = {
      other: [
        { 
          id: 1, 
          title: "Mercenary", 
          price: 35, 
          description: "This meeple will fight for you for an hour. Purchase to skip a required hour of sieging!", 
          image: this.element.dataset.mercenaryImage, 
          maxPerWeek: 10, 
          priceIncreases: true, 
          oneTime: false 
        },
        { 
          id: 1.5, 
          title: "Time travelling mercenary", 
          price: 40, 
          description: "This mercenary will go back in time to fight your past battles. It will help get you back in the siege if you failed previously. Contact @Olive after buying to have its effects applied. NOTE: buying time travelling mercenaries may cause you to lose coins and/or have shop items forcably refunded! Make sure you're aware of the dangers of time travel...", 
          image: this.element.dataset.timeTravelImage, 
          limitedQuantity: true, 
          dynamicQuantity: true, 
          oneTime: false 
        },
        { 
          id: 2, 
          title: "Unlock Orange Meeple", 
          price: 50, 
          description: "Not feeling your color? Try orange!", 
          image: this.element.dataset.orangeMeepleImage, 
          oneTime: true 
        }
      ]
    }

    // Add cosmetics and physical items from values
    if (this.purchasableCosmeticsValue) {
      this.purchasableCosmeticsValue.forEach((cosmetic, index) => {
        allShopItems.other.push({
          id: 100 + index,
          title: cosmetic.name,
          price: cosmetic.cost,
          description: cosmetic.description || 'A cosmetic item for your meeple!',
          image: cosmetic.image_url,
          oneTime: true,
          isCosmetic: true
        })
      })
    }

    if (this.purchasablePhysicalItemsValue) {
      this.purchasablePhysicalItemsValue.forEach((item, index) => {
        allShopItems.other.push({
          id: 200 + index,
          title: item.name,
          price: item.cost,
          description: item.description || 'A physical item that will be shipped to you!',
          image: item.image_url,
          oneTime: false,
          isPhysicalItem: true,
          digital: item.digital
        })
      })
    }

    this.allShopItems = allShopItems
    this.filterShopItems()
  }

  loadInitialData() {
    this.filterShopItems()
    this.loadUserCoins()
    this.loadMercenaryPrice()
    this.loadTimeTravellingMercenaryData()
    this.loadTechTreeData()
    this.loadUserPurchases()
    this.loadMainDevice()
  }

  filterShopItems() {
    this.shopItems = {}
    Object.keys(this.allShopItems).forEach(category => {
      this.shopItems[category] = this.allShopItems[category].filter(item => {
        if (item.title === 'Time travelling mercenary') {
          if (this.timeTravellingMercenaryQuantity <= 0) {
            return false
          }
        }
        return !item.oneTime || !this.purchasedOneTimeItemsValue.includes(item.title)
      })
    })
  }

  async loadUserCoins() {
    try {
      const response = await fetch('/market/user_coins', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      const data = await response.json()
      this.userCoins = data.coins
      if (this.hasUserCoinsTarget) {
        this.userCoinsTarget.textContent = this.userCoins
      }
    } catch (error) {
      console.error('Failed to load user coins:', error)
    }
  }

  async loadMercenaryPrice() {
    try {
      const response = await fetch('/market/mercenary_price', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      const data = await response.json()
      this.mercenaryPrice = data.price || 35
      this.mercenaryCount = data.count || 0
      this.renderShopItems()
    } catch (error) {
      console.warn('Failed to load mercenary price:', error)
      this.mercenaryPrice = 35
      this.mercenaryCount = 0
    }
  }

  async loadTimeTravellingMercenaryData() {
    try {
      const response = await fetch('/market/time_travelling_mercenary_data', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      const data = await response.json()
      this.timeTravellingMercenaryQuantity = data.quantity || 0
      this.timeTravellingMercenaryInventory = data.inventory_count || 0
      this.filterShopItems()
      this.renderShopItems()
    } catch (error) {
      console.warn('Failed to load time travelling mercenary data:', error)
    }
  }

  async loadTechTreeData() {
    try {
      const response = await fetch('/market/tech_tree_data', {
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      const data = await response.json()
      this.techTreeData = data
      console.log('Tech tree data loaded')
    } catch (error) {
      console.error('Failed to preload tech tree:', error)
      this.techTreeData = {}
    }
  }

  async loadUserPurchases() {
    try {
      const response = await fetch('/market/user_purchases', {
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      const data = await response.json()
      this.techTreePurchases = {}
      data.purchases.forEach(p => {
        this.techTreePurchases[p.item_name] = p.quantity
      })
      console.log('Purchases loaded:', this.techTreePurchases)
    } catch (error) {
      console.error('Failed to preload purchases:', error)
    }
  }

  async loadMainDevice() {
    try {
      const response = await fetch('/market/get_main_device', {
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      const data = await response.json()
      this.userMainDeviceBranchId = data.main_device || null
      console.log('Main device loaded from server:', this.userMainDeviceBranchId)
    } catch (error) {
      console.error('Failed to preload main device:', error)
      this.userMainDeviceBranchId = null
    }
  }

  // Shop actions
  openShop() {
    this.marketDialogueTarget.classList.remove('visible')
    this.shopInterfaceTarget.classList.add('visible')
    this.renderShopItems()
  }

  closeShop() {
    this.shopInterfaceTarget.classList.remove('visible')
    this.marketDialogueTarget.classList.add('visible')
  }

  renderShopItems() {
    if (!this.hasShopItemsGridTarget) return

    this.shopItemsGridTarget.innerHTML = ''

    Object.keys(this.shopItems).forEach(category => {
      this.shopItems[category].forEach(item => {
        const card = this.createShopItemCard(item)
        this.shopItemsGridTarget.appendChild(card)
      })
    })
  }

  createShopItemCard(item) {
    const card = document.createElement('div')
    card.className = 'shop-item-card'
    
    const price = this.getShopItemDisplayPrice(item)
    const canAfford = this.userCoins >= price
    
    if (!canAfford) {
      card.classList.add('disabled')
    }

    const imageContainer = document.createElement('div')
    imageContainer.className = 'shop-item-image-container'
    
    if (item.isCosmetic) {
      const bgImg = document.createElement('img')
      bgImg.src = this.meepleAssetValue
      bgImg.className = 'shop-item-meeple-bg'
      bgImg.alt = ''
      
      const itemImg = document.createElement('img')
      itemImg.src = item.image
      itemImg.className = 'shop-item-image cosmetic has-meeple'
      itemImg.alt = item.title
      
      imageContainer.appendChild(bgImg)
      imageContainer.appendChild(itemImg)
    } else {
      const itemImg = document.createElement('img')
      itemImg.src = item.image
      itemImg.className = 'shop-item-image'
      if (item.title === 'Mercenary' || item.title === 'Time travelling mercenary' || item.title === 'Unlock Orange Meeple') {
        itemImg.className += ' mercenary'
      } else if (item.isPhysicalItem) {
        itemImg.className += ' physical'
      }
      itemImg.alt = item.title
      imageContainer.appendChild(itemImg)
    }
    
    card.appendChild(imageContainer)
    
    const nameDiv = document.createElement('div')
    nameDiv.className = 'shop-item-name'
    nameDiv.textContent = item.title
    card.appendChild(nameDiv)
    
    const costDiv = document.createElement('div')
    costDiv.className = 'shop-item-cost'
    const coinImg = document.createElement('img')
    coinImg.src = this.coinAssetValue
    coinImg.className = 'shop-item-cost-icon'
    coinImg.alt = 'coins'
    costDiv.appendChild(coinImg)
    costDiv.appendChild(document.createTextNode(' ' + price))
    card.appendChild(costDiv)
    
    if (item.maxPerWeek) {
      const stockDiv = document.createElement('div')
      stockDiv.className = 'shop-item-stock'
      stockDiv.textContent = `${this.mercenaryCount}/${item.maxPerWeek} this week`
      card.appendChild(stockDiv)
    }
    
    if (item.limitedQuantity && item.title === 'Time travelling mercenary') {
      const stockDiv = document.createElement('div')
      stockDiv.className = 'shop-item-stock'
      stockDiv.textContent = `${this.timeTravellingMercenaryInventory}/${this.timeTravellingMercenaryQuantity} available`
      card.appendChild(stockDiv)
    }

    card.onclick = () => this.openItemModal(item)
    return card
  }

  getShopItemDisplayPrice(item) {
    if (item.title === 'Mercenary') {
      return this.mercenaryPrice
    }
    return item.price
  }

  openItemModal(item) {
    this.currentItem = item
    const price = this.getShopItemDisplayPrice(item)
    
    this.modalItemImageContainerTarget.innerHTML = ''
    
    if (item.isCosmetic) {
      const bgImg = document.createElement('img')
      bgImg.src = this.meepleAssetValue
      bgImg.className = 'shop-item-modal-meeple-bg'
      bgImg.alt = ''
      
      const itemImg = document.createElement('img')
      itemImg.src = item.image
      itemImg.className = 'shop-item-modal-image has-meeple'
      itemImg.alt = item.title
      
      this.modalItemImageContainerTarget.appendChild(bgImg)
      this.modalItemImageContainerTarget.appendChild(itemImg)
    } else {
      const itemImg = document.createElement('img')
      itemImg.src = item.image
      itemImg.className = 'shop-item-modal-image'
      itemImg.alt = item.title
      
      this.modalItemImageContainerTarget.appendChild(itemImg)
    }
    
    this.modalItemTitleTarget.textContent = item.title
    this.modalItemDescriptionTarget.textContent = item.description
    this.modalItemPriceTarget.textContent = `${price} coins`
    
    let stockText = ''
    if (item.maxPerWeek) {
      stockText = `${this.mercenaryCount}/${item.maxPerWeek} purchased this week`
    } else if (item.limitedQuantity && item.title === 'Time travelling mercenary') {
      stockText = `${this.timeTravellingMercenaryInventory}/${this.timeTravellingMercenaryQuantity} available`
    }
    this.modalItemStockTarget.textContent = stockText

    const canAfford = this.userCoins >= price
    this.modalBuyButtonTarget.disabled = !canAfford
    
    this.shopItemModalTarget.classList.add('visible')
    this.positionModalOnActiveInterface(this.shopItemModalTarget)
  }

  closeItemModal() {
    this.shopItemModalTarget.classList.remove('visible')
    this.currentItem = null
  }

  async confirmPurchase() {
    if (!this.currentItem) return

    const price = this.getShopItemDisplayPrice(this.currentItem)
    
    if (this.userCoins < price) {
      this.showStatus('error', 'Not enough coins!')
      return
    }

    this.showStatus('loading', 'Processing purchase...')
    
    try {
      const response = await fetch('/market/purchase', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          item_name: this.currentItem.title,
          coins_spent: price
        })
      })
      const data = await response.json()
      
      if (data.success) {
        this.showStatus('confirmation', data.message || 'Purchase successful!')
        
        this.userCoins -= price
        this.userCoinsTarget.textContent = this.userCoins

        if (this.currentItem.oneTime) {
          this.purchasedOneTimeItemsValue.push(this.currentItem.title)
          this.filterShopItems()
        }

        if (this.currentItem.title === 'Mercenary') {
          this.mercenaryCount++
          this.loadMercenaryPrice()
        }

        if (this.currentItem.title === 'Time travelling mercenary') {
          this.timeTravellingMercenaryInventory++
          if (this.timeTravellingMercenaryInventory >= this.timeTravellingMercenaryQuantity) {
            this.filterShopItems()
          }
        }

        this.closeItemModal()
        this.renderShopItems()
      } else {
        this.showStatus('error', data.error || 'Purchase failed!')
      }
    } catch (error) {
      console.error('Purchase error:', error)
      this.showStatus('error', 'Purchase failed. Please try again.')
    }
  }

  // Tech Tree actions
  openDeviceUpgrades() {
    this.marketDialogueTarget.classList.remove('visible')
    this.techTreeInterfaceTarget.classList.add('visible')
    
    this.updateTechTreeCoins()
    
    if (!this.techTreeData || this.userMainDeviceBranchId === null) {
      this.showStatus('loading', 'Loading tech tree data...')
      let attempts = 0
      const maxAttempts = 100
      
      this.checkInterval = setInterval(() => {
        attempts++
        
        if (this.techTreeData && this.userMainDeviceBranchId !== null) {
          clearInterval(this.checkInterval)
          this.checkInterval = null
          this.closeStatusModal()
          this.initializeTechTree()
        } else if (attempts >= maxAttempts) {
          clearInterval(this.checkInterval)
          this.checkInterval = null
          console.error('Timeout waiting for tech tree data or main device')
          this.showStatus('error', 'Failed to load tech tree data. Please refresh the page.')
        }
      }, 100)
      return
    }
    
    this.initializeTechTree()
  }

  closeTechTree() {
    this.techTreeInterfaceTarget.classList.remove('visible')
    this.marketDialogueTarget.classList.add('visible')
  }

  initializeTechTree() {
    console.log('Initializing tech tree. userMainDeviceBranchId:', this.userMainDeviceBranchId)
    
    if (this.userMainDeviceBranchId) {
      this.viewingDeviceType = this.findDeviceTypeForBranch(this.userMainDeviceBranchId)
      this.currentBranchId = this.userMainDeviceBranchId
      console.log('Loading saved device:', this.viewingDeviceType, this.currentBranchId)
    } else {
      this.showInitialDeviceSelection()
      return
    }
    
    this.updateSwitchButton()
    this.renderTechTree()
  }

  findDeviceTypeForBranch(branchId) {
    if (!this.techTreeData) return null
    
    for (const [deviceType, deviceData] of Object.entries(this.techTreeData)) {
      if (deviceData.branches && deviceData.branches[branchId]) {
        return deviceType
      }
    }
    return null
  }

  showInitialDeviceSelection() {
    this.initialSelectionTitleTarget.textContent = 'Choose your device type'
    this.initialOptionsTarget.innerHTML = ''
    
    const devices = []
    
    if (this.userInSupportedRegionValue) {
      devices.push(
        { id: 'laptop', title: 'Laptop', description: 'Get a framework' },
        { id: 'tablet', title: 'Tablet', description: 'Apple, Samsung, or OnePlus!' }
      )
    } else {
      devices.push(
        { id: 'laptop_grant', title: 'Laptop Grant', description: 'Get a $650 laptop grant to buy your own device' },
        { id: 'tablet', title: 'Tablet', description: 'Apple, Samsung, or OnePlus!' }
      )
    }
    
    devices.forEach(device => {
      const btn = document.createElement('button')
      btn.className = 'initial-option-btn'
      btn.onclick = () => this.selectDeviceType(device.id)
      btn.innerHTML = `
        <div class="initial-option-title">${device.title}</div>
        <div class="initial-option-desc">${device.description}</div>
      `
      this.initialOptionsTarget.appendChild(btn)
    })
    
    this.initialSelectionModalTarget.classList.add('visible')
  }

  selectDeviceType(deviceType) {
    this.initialSelectionModalTarget.classList.remove('visible')
    
    if (deviceType === 'laptop_grant') {
      const hasUpgrades = this.hasDeviceSpecificUpgrades()
      
      if (hasUpgrades) {
        this.showConfirmationModal(
          'You have device-specific upgrades. Selecting the laptop grant will refund all your tech tree purchases. Continue?',
          () => {
            this.saveMainDevice('laptop_grant_base', true)
          }
        )
      } else {
        this.setMainDevice('laptop_grant_base')
      }
      return
    }
    
    this.currentDevice = deviceType
    this.selectedBranch = null
    this.updateSwitchButton()
    this.renderTechTree()
  }

  async setMainDevice(deviceId) {
    this.showStatus('loading', 'Switching your device...')
    
    try {
      const response = await fetch('/market/set_main_device', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ device_id: deviceId, refund: false })
      })
      const data = await response.json()
      
      if (data.success) {
        console.log('Main device set successfully')
        this.userMainDeviceBranchId = deviceId
        this.currentBranchId = deviceId
        this.viewingDeviceType = this.findDeviceTypeForBranch(deviceId)
        this.closeStatusModal()
        this.updateSwitchButton()
        this.renderTechTree()
      } else {
        this.closeStatusModal()
        this.showStatus('error', data.error || 'Failed to set device')
      }
    } catch (error) {
      console.error('Failed to set main device:', error)
      this.closeStatusModal()
      this.showStatus('error', 'Failed to set device')
    }
  }

  switchViewedDevice() {
    if (this.userInSupportedRegionValue) {
      this.viewingDeviceType = this.viewingDeviceType === 'laptop' ? 'tablet' : 'laptop'
    } else {
      this.viewingDeviceType = this.viewingDeviceType === 'laptop_grant' ? 'tablet' : 'laptop_grant'
    }
    
    const userDeviceType = this.userMainDeviceBranchId ? this.findDeviceTypeForBranch(this.userMainDeviceBranchId) : null
    
    if (this.viewingDeviceType === userDeviceType) {
      this.currentBranchId = this.userMainDeviceBranchId
    } else {
      this.currentBranchId = null
    }
    
    this.updateSwitchButton()
    this.renderTechTree()
  }

  updateSwitchButton() {
    if (this.viewingDeviceType) {
      this.switchDeviceBtnTarget.style.display = 'inline-block'
      
      if (this.userInSupportedRegionValue) {
        this.switchDeviceTextTarget.textContent = this.viewingDeviceType === 'laptop' ? 'Tablet' : 'Laptop'
      } else {
        this.switchDeviceTextTarget.textContent = this.viewingDeviceType === 'laptop_grant' ? 'Tablet' : 'Laptop Grant'
      }
    } else {
      this.switchDeviceBtnTarget.style.display = 'none'
    }
  }

  async updateTechTreeCoins() {
    try {
      const response = await fetch('/market/user_coins', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })
      const data = await response.json()
      this.userCoins = data.coins
      if (this.hasTechTreeCoinsTarget) {
        this.techTreeCoinsTarget.textContent = this.userCoins
      }
    } catch (error) {
      console.error('Failed to update tech tree coins:', error)
    }
  }

  updateGrantTotal() {
    if (this.viewingDeviceType === 'laptop_grant') {
      this.grantTotalDisplayTarget.style.display = 'block'
      this.grantTotalAmountTarget.textContent = this.calculateGrantTotal()
    } else {
      this.grantTotalDisplayTarget.style.display = 'none'
    }
  }

  calculateGrantTotal() {
    let total = 650
    
    if (this.techTreePurchases['+$10 Grant']) {
      total += this.techTreePurchases['+$10 Grant'] * 10
    }
    if (this.techTreePurchases['+$50 Grant']) {
      total += this.techTreePurchases['+$50 Grant'] * 50
    }
    if (this.techTreePurchases['+$100 Grant']) {
      total += this.techTreePurchases['+$100 Grant'] * 100
    }
    
    return total
  }

  renderTechTree() {
    if (!this.viewingDeviceType || !this.techTreeData) return
    
    this.updateGrantTotal()
    
    const deviceData = this.techTreeData[this.viewingDeviceType]
    this.techTreeNodesTarget.innerHTML = ''
    this.techTreeEdgesTarget.innerHTML = ''
    
    const rootNode = deviceData.initialNode
    const rootEl = this.createRootNode(rootNode, deviceData)
    this.techTreeNodesTarget.appendChild(rootEl)
    
    if (!this.currentBranchId) {
      if (rootNode.options && rootNode.options.length > 0) {
        return
      }
    }
    
    const branches = this.currentBranchId ? deviceData.branches[this.currentBranchId] : {}
    if (!branches) return
    
    this.renderTechTreeNodes(branches)
  }

  createRootNode(rootNode, deviceData) {
    const rootEl = document.createElement('div')
    rootEl.className = 'tech-node root-node'
    rootEl.style.left = '0px'
    rootEl.style.top = '0px'
    
    if (rootNode.options && rootNode.options.length > 0) {
      if (this.currentBranchId) {
        const selectedOption = rootNode.options.find(opt => opt.id === this.currentBranchId)
        if (selectedOption) {
          rootEl.innerHTML = `
            <div class="tech-node-title">${selectedOption.title}</div>
            <div style="font-size: 0.75rem; margin-top: 0.5rem; color: #8b5a3c;">Click to swap</div>
          `
        } else {
          rootEl.innerHTML = `<div class="tech-node-title">${rootNode.title}</div>`
        }
      } else {
        const optionsHtml = rootNode.options.map(opt => 
          `<div><strong>${opt.title}</strong></div>`
        ).join('')
        
        rootEl.innerHTML = `
          <div class="tech-node-title">${rootNode.title}</div>
          <div style="font-size: 0.85rem; margin-top: 0.5rem;">${optionsHtml}</div>
          <div style="font-size: 0.75rem; margin-top: 0.5rem; color: #8b5a3c;">Click to select</div>
        `
      }
      
      rootEl.onclick = () => this.showRootOptions(rootNode.options)
    } else {
      if (this.currentBranchId) {
        rootEl.innerHTML = `
          <div class="tech-node-title">${rootNode.title}</div>
          <div style="font-size: 0.75rem; margin-top: 0.5rem; color: #8b5a3c;">Click to switch device</div>
        `
      } else {
        rootEl.innerHTML = `
          <div class="tech-node-title">${rootNode.title}</div>
          <div style="font-size: 0.75rem; margin-top: 0.5rem; color: #8b5a3c;">Click to select</div>
        `
      }
      
      rootEl.onclick = () => {
        if (this.viewingDeviceType === 'laptop_grant') {
          const hasUpgrades = this.hasDeviceSpecificUpgrades()
          
          if (hasUpgrades) {
            this.showConfirmationModal(
              'You have device-specific upgrades. Selecting the laptop grant will refund all your tech tree purchases. Continue?',
              () => {
                this.saveMainDevice('laptop_grant_base', true)
              }
            )
          } else {
            this.setMainDevice('laptop_grant_base')
          }
        } else {
          this.showInitialDeviceSelection()
        }
      }
    }
    
    return rootEl
  }

  renderTechTreeNodes(branches) {
    const nodes = []
    const edges = []
    
    Object.entries(branches).forEach(([direction, nodeData]) => {
      const pos = this.getNodePosition(direction)
      
      nodes.push({
        ...nodeData,
        x: pos.x,
        y: pos.y,
        direction
      })
      
      if (nodeData.requires) {
        const reqTitles = nodeData.requires.split(',').map(s => s.trim())
        reqTitles.forEach(reqTitle => {
          const reqNode = nodes.find(n => n.title === reqTitle)
          if (reqNode) {
            edges.push({
              from: reqNode,
              to: nodeData,
              fromX: reqNode.x,
              fromY: reqNode.y,
              toX: pos.x,
              toY: pos.y
            })
          }
        })
      } else {
        edges.push({
          from: null,
          to: nodeData,
          fromX: 0,
          fromY: 0,
          toX: pos.x,
          toY: pos.y
        })
      }
    })
    
    nodes.forEach(node => {
      const nodeEl = this.createTechNode(node, nodes)
      this.techTreeNodesTarget.appendChild(nodeEl)
    })
    
    this.renderTechTreeEdges(edges, nodes)
  }

  createTechNode(node, allNodes) {
    const nodeEl = document.createElement('div')
    nodeEl.className = 'tech-node'
    nodeEl.style.left = `${node.x}px`
    nodeEl.style.top = `${node.y}px`
    nodeEl.setAttribute('data-node-id', node.id)
    
    const purchased = this.techTreePurchases[node.title] || 0
    const maxPurchases = this.calculateMaxPurchases(node)
    const isLocked = !this.isNodeAvailable(node, allNodes)
    const isMaxed = maxPurchases !== Infinity && purchased >= maxPurchases
    const isAffordable = this.userCoins >= node.price
    
    if (isLocked) nodeEl.classList.add('locked')
    if (purchased > 0) nodeEl.classList.add('owned')
    if (isMaxed) nodeEl.classList.add('maxed')
    if (!isAffordable && !isLocked) nodeEl.classList.add('unaffordable')
    
    let counterText = ''
    if (maxPurchases === Infinity) {
      if (purchased > 0) counterText = `<div class="tech-node-counter">Owned: ${purchased}</div>`
    } else if (maxPurchases > 1 || node.dynamicMaxPurchases) {
      counterText = `<div class="tech-node-counter">${purchased}/${maxPurchases}</div>`
    }
    
    nodeEl.innerHTML = `
      <div class="tech-node-title">${node.title}</div>
      <div class="tech-node-price">
        <img src="${this.coinAssetValue}" class="tech-node-price-icon" alt="coins">
        ${node.price}
      </div>
      ${counterText}
    `
    
    nodeEl.onclick = () => this.openTechNodeModal(node, isLocked, isMaxed, isAffordable, purchased, maxPurchases)
    
    return nodeEl
  }

  renderTechTreeEdges(edges, nodes) {
    if (edges.length === 0) return
    
    let minX = 0, maxX = 0, minY = 0, maxY = 0
    nodes.forEach(node => {
      minX = Math.min(minX, node.x)
      maxX = Math.max(maxX, node.x)
      minY = Math.min(minY, node.y)
      maxY = Math.max(maxY, node.y)
    })
    
    const padding = 400
    const width = maxX - minX + padding * 2
    const height = maxY - minY + padding * 2
    const offsetX = -minX + padding
    const offsetY = -minY + padding
    
    this.techTreeEdgesTarget.setAttribute('width', width)
    this.techTreeEdgesTarget.setAttribute('height', height)
    this.techTreeEdgesTarget.style.marginLeft = `${minX - padding}px`
    this.techTreeEdgesTarget.style.marginTop = `${minY - padding}px`
    
    edges.forEach(edge => {
      const fromRadius = edge.fromX === 0 && edge.fromY === 0 ? 90 : 70
      const toRadius = 70
      
      const dx = edge.toX - edge.fromX
      const dy = edge.toY - edge.fromY
      const angle = Math.atan2(dy, dx)
      
      const x1 = edge.fromX + Math.cos(angle) * fromRadius
      const y1 = edge.fromY + Math.sin(angle) * fromRadius
      
      const x2 = edge.toX - Math.cos(angle) * toRadius
      const y2 = edge.toY - Math.sin(angle) * toRadius
      
      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line')
      line.setAttribute('x1', x1 + offsetX)
      line.setAttribute('y1', y1 + offsetY)
      line.setAttribute('x2', x2 + offsetX)
      line.setAttribute('y2', y2 + offsetY)
      line.setAttribute('class', 'tech-edge')
      
      const toNode = edge.to
      const purchased = this.techTreePurchases[toNode.title] || 0
      const isLocked = !this.isNodeAvailable(toNode, nodes)
      
      if (isLocked) line.classList.add('locked')
      if (purchased > 0) line.classList.add('owned')
      
      this.techTreeEdgesTarget.appendChild(line)
    })
  }

  getNodePosition(direction) {
    const multiplier = this.DIRECTION_MULTIPLIERS[direction]
    if (!multiplier) {
      console.warn('Unknown direction:', direction)
      return { x: 0, y: 0 }
    }
    
    return {
      x: multiplier[0] * this.BASE_DISTANCE,
      y: multiplier[1] * this.BASE_DISTANCE
    }
  }

  isNodeAvailable(node, allNodes) {
    if (!node.requires) return true
    
    const reqTitles = node.requires.split(',').map(s => s.trim())
    return reqTitles.every(reqTitle => {
      return (this.techTreePurchases[reqTitle] || 0) > 0
    })
  }

  calculateMaxPurchases(node) {
    if (node.dynamicMaxPurchases) {
      const match = node.dynamicMaxPurchases.match(/^(.+)\s*\+\s*(\d+)$/)
      if (match) {
        const baseTitle = match[1].trim()
        const additional = parseInt(match[2], 10)
        const basePurchased = this.techTreePurchases[baseTitle] || 0
        return basePurchased + additional
      }
    }
    
    if (node.maxPurchases === null || node.maxPurchases === undefined) {
      if (node.title && node.title.includes('Grant')) {
        return Infinity
      }
      return 1
    }
    
    return node.maxPurchases
  }

  openTechNodeModal(node, isLocked, isMaxed, isAffordable, purchased, maxPurchases) {
    this.currentTechNode = node
    
    this.techNodeModalTitleTarget.textContent = node.title
    this.techNodeModalDescriptionTarget.textContent = node.description || ''
    
    this.techNodeModalPriceTarget.innerHTML = `
      <img src="${this.coinAssetValue}" class="tech-node-modal-price-icon" alt="coins">
      ${node.price}
    `
    
    this.techNodeModalStatusTarget.style.display = 'none'
    this.techNodeModalStatusTarget.className = 'tech-node-modal-status'
    
    if (isLocked) {
      this.techNodeModalStatusTarget.style.display = 'block'
      this.techNodeModalStatusTarget.classList.add('locked')
      this.techNodeModalStatusTarget.textContent = 'Locked - Purchase prerequisites first'
    }
    
    let infoText = ''
    
    if (maxPurchases === Infinity) {
      if (purchased > 0) infoText = `Owned: ${purchased}`
    } else if (maxPurchases > 1) {
      infoText = `Purchased: ${purchased}/${maxPurchases}`
    } else if (purchased > 0) {
      infoText = 'Already owned'
    }
    
    if (node.requires) {
      const prereqs = node.requires.split(',').map(s => s.trim()).join(', ')
      if (infoText) infoText += '<br>'
      infoText += `Requires: ${prereqs}`
    }
    
    this.techNodeModalInfoTarget.innerHTML = infoText
    
    this.techNodeBuyButtonTarget.disabled = isLocked || isMaxed || !isAffordable
    
    if (!isAffordable && !isLocked && !isMaxed) {
      this.techNodeBuyButtonTarget.textContent = 'Not enough coins'
    } else if (isMaxed) {
      this.techNodeBuyButtonTarget.textContent = 'Maxed'
    } else {
      this.techNodeBuyButtonTarget.textContent = 'Buy'
    }
    
    this.techNodeModalTarget.classList.add('visible')
    this.positionModalOnActiveInterface(this.techNodeModalTarget)
  }

  closeTechNodeModal() {
    this.techNodeModalTarget.classList.remove('visible')
    this.currentTechNode = null
  }

  async confirmTechNodePurchase() {
    if (!this.currentTechNode) return
    
    const node = this.currentTechNode
    
    if (this.userCoins < node.price) {
      this.showStatus('error', 'Not enough coins!')
      return
    }
    
    const purchased = this.techTreePurchases[node.title] || 0
    const maxPurchases = this.calculateMaxPurchases(node)
    
    if (maxPurchases !== Infinity && purchased >= maxPurchases) {
      this.showStatus('error', 'Already purchased maximum!')
      return
    }
    
    this.showStatus('loading', 'Processing purchase...')
    
    try {
      const response = await fetch('/market/purchase', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          item_name: node.title,
          coins_spent: node.price
        })
      })
      const data = await response.json()
      
      if (data.success) {
        this.showStatus('confirmation', data.message || 'Purchase successful!')
        this.userCoins -= node.price
        this.techTreePurchases[node.title] = (this.techTreePurchases[node.title] || 0) + 1
        this.updateTechTreeCoins()
        this.closeTechNodeModal()
        this.renderTechTree()
      } else {
        this.showStatus('error', data.error || 'Purchase failed!')
      }
    } catch (error) {
      console.error('Purchase error:', error)
      this.showStatus('error', 'Purchase failed. Please try again.')
    }
  }

  showRootOptions(options) {
    this.initialSelectionTitleTarget.textContent = 'Choose your configuration'
    this.initialOptionsTarget.innerHTML = ''
    
    const hasPurchases = this.hasDeviceSpecificUpgrades()
    
    options.forEach(option => {
      const btn = document.createElement('button')
      btn.className = 'initial-option-btn'
      const isCurrentlySaved = option.id === this.userMainDeviceBranchId
      
      btn.onclick = () => this.selectBranchOption(option.id, isCurrentlySaved, hasPurchases)
      
      btn.innerHTML = `
        <div class="initial-option-title">${option.title}${isCurrentlySaved ? ' (Current)' : ''}</div>
        <div class="initial-option-desc">${option.description}</div>
      `
      this.initialOptionsTarget.appendChild(btn)
    })
    
    this.initialSelectionModalTarget.classList.add('visible')
  }

  selectBranchOption(branchId, isCurrentlySaved, hasPurchases) {
    console.log('selectBranchOption:', branchId, 'currently saved:', isCurrentlySaved)
    
    if (isCurrentlySaved) {
      this.initialSelectionModalTarget.classList.remove('visible')
      return
    }
    
    console.log('Switching device with purchases:', { hasPurchases, from: this.userMainDeviceBranchId, to: branchId })
    
    if (hasPurchases) {
      this.showConfirmationModal(
        'Switching device will refund all tech tree purchases. Continue?',
        () => {
          this.saveMainDevice(branchId, true)
        }
      )
    } else {
      this.saveMainDevice(branchId, false)
    }
  }

  async saveMainDevice(branchId, shouldRefund) {
    console.log('Saving main device:', branchId, 'with refund:', shouldRefund)
    
    this.showStatus('loading', shouldRefund ? 'Refunding purchases and switching device...' : 'Switching device...')
    
    try {
      const response = await fetch('/market/set_main_device', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ device_id: branchId, refund: shouldRefund })
      })
      const data = await response.json()
      
      if (data.success) {
        console.log('Main device saved successfully')
        this.userMainDeviceBranchId = branchId
        this.currentBranchId = branchId
        this.viewingDeviceType = this.findDeviceTypeForBranch(branchId)
        
        this.initialSelectionModalTarget.classList.remove('visible')
        this.closeStatusModal()
        
        await this.loadUserPurchases()
        await this.updateTechTreeCoins()
        
        this.updateSwitchButton()
        this.renderTechTree()
        
        if (shouldRefund) {
          this.showStatus('confirmation', 'Device switched and purchases refunded!')
        }
      } else {
        this.showStatus('error', data.error || 'Failed to update device')
      }
    } catch (error) {
      console.error('Save main device error:', error)
      this.showStatus('error', 'Failed to update device')
    }
  }

  hasDeviceSpecificUpgrades() {
    if (!this.userMainDeviceBranchId || !this.techTreeData) return false
    
    const deviceType = this.findDeviceTypeForBranch(this.userMainDeviceBranchId)
    if (!deviceType) return false
    
    const deviceData = this.techTreeData[deviceType]
    if (!deviceData || !deviceData.branches || !deviceData.branches[this.userMainDeviceBranchId]) return false
    
    const branches = deviceData.branches[this.userMainDeviceBranchId]
    
    for (const [direction, nodeData] of Object.entries(branches)) {
      if (this.techTreePurchases[nodeData.title] > 0) {
        return true
      }
    }
    
    return false
  }

  // Zoom and pan
  zoomIn() {
    this.techTreeZoom = Math.min(this.techTreeZoom * 1.2, 3)
    this.applyTransform()
  }

  zoomOut() {
    this.techTreeZoom = Math.max(this.techTreeZoom / 1.2, 0.3)
    this.applyTransform()
  }

  resetZoom() {
    this.techTreeZoom = 1
    this.techTreePan = { x: 0, y: 0 }
    this.applyTransform()
  }

  applyTransform() {
    this.techTreeContainerTarget.style.transform = `translate(${this.techTreePan.x}px, ${this.techTreePan.y}px) scale(${this.techTreeZoom})`
  }

  setupTechTreeListeners() {
    if (!this.hasTechTreeViewportTarget) return
    
    this.mousedownHandler = this.handleMouseDown.bind(this)
    this.mousemoveHandler = this.handleMouseMove.bind(this)
    this.mouseupHandler = this.handleMouseUp.bind(this)
    this.mouseleaveHandler = this.handleMouseLeave.bind(this)
    this.wheelHandler = this.handleWheel.bind(this)
    
    this.techTreeViewportTarget.addEventListener('mousedown', this.mousedownHandler)
    this.techTreeViewportTarget.addEventListener('mousemove', this.mousemoveHandler)
    this.techTreeViewportTarget.addEventListener('mouseup', this.mouseupHandler)
    this.techTreeViewportTarget.addEventListener('mouseleave', this.mouseleaveHandler)
    this.techTreeViewportTarget.addEventListener('wheel', this.wheelHandler)
  }

  handleMouseDown(e) {
    if (e.target === this.techTreeViewportTarget || e.target.closest('.tech-tree-container')) {
      e.preventDefault()
      this.isPanning = true
      this.panStart = { x: e.clientX - this.techTreePan.x, y: e.clientY - this.techTreePan.y }
      this.techTreeViewportTarget.style.cursor = 'grabbing'
    }
  }

  handleMouseMove(e) {
    if (this.isPanning) {
      this.techTreePan.x = e.clientX - this.panStart.x
      this.techTreePan.y = e.clientY - this.panStart.y
      this.applyTransform()
    }
  }

  handleMouseUp() {
    this.isPanning = false
    this.techTreeViewportTarget.style.cursor = 'default'
  }

  handleMouseLeave() {
    this.isPanning = false
    this.techTreeViewportTarget.style.cursor = 'default'
  }

  handleWheel(e) {
    if (e.ctrlKey) {
      e.preventDefault()
      const delta = e.deltaY > 0 ? 0.9 : 1.1
      this.techTreeZoom = Math.max(0.3, Math.min(3, this.techTreeZoom * delta))
      this.applyTransform()
    }
  }

  // Modal utilities
  positionModalOnActiveInterface(modal) {
    let container = null
    
    if (this.techTreeInterfaceTarget.classList.contains('visible')) {
      container = this.techTreeInterfaceTarget
    } else if (this.shopInterfaceTarget.classList.contains('visible')) {
      container = this.shopInterfaceTarget
    }
    
    if (container) {
      const rect = container.getBoundingClientRect()
      modal.style.position = 'fixed'
      modal.style.left = `${rect.left + rect.width / 2}px`
      modal.style.top = `${rect.top + rect.height / 2}px`
      modal.style.transform = 'translate(-50%, -50%)'
    } else {
      modal.style.position = 'fixed'
      modal.style.left = '50%'
      modal.style.top = '50%'
      modal.style.transform = 'translate(-50%, -50%)'
    }
  }

  showStatus(type, message) {
    this.statusModalTextTarget.textContent = message
    this.statusModalTarget.className = `status-modal visible ${type}`
    
    if (type === 'loading') {
      this.statusModalButtonTarget.style.display = 'none'
    } else {
      this.statusModalButtonTarget.style.display = 'inline-block'
      this.statusModalButtonTarget.textContent = 'OK'
    }
    
    this.positionModalOnActiveInterface(this.statusModalTarget)
  }

  showConfirmationModal(message, onConfirm) {
    this.statusModalTextTarget.textContent = message
    this.statusModalTarget.className = 'status-modal visible confirmation'
    
    const buttonContainer = document.createElement('div')
    buttonContainer.style.display = 'flex'
    buttonContainer.style.gap = '1rem'
    buttonContainer.style.justifyContent = 'center'
    buttonContainer.style.marginTop = '1rem'
    
    const continueButton = document.createElement('button')
    continueButton.className = 'shop-button'
    continueButton.textContent = 'Continue'
    continueButton.style.backgroundColor = '#8b4513'
    continueButton.style.color = 'white'
    
    const cancelButton = document.createElement('button')
    cancelButton.className = 'shop-button'
    cancelButton.textContent = 'Cancel'
    cancelButton.style.backgroundColor = '#6c757d'
    cancelButton.style.color = 'white'
    
    buttonContainer.appendChild(continueButton)
    buttonContainer.appendChild(cancelButton)
    
    this.statusModalButtonTarget.style.display = 'none'
    this.statusModalTarget.appendChild(buttonContainer)
    
    this.positionModalOnActiveInterface(this.statusModalTarget)
    
    continueButton.onclick = () => {
      this.statusModalTarget.removeChild(buttonContainer)
      this.statusModalButtonTarget.style.display = 'inline-block'
      this.closeStatusModal()
      onConfirm()
    }
    
    cancelButton.onclick = () => {
      this.statusModalTarget.removeChild(buttonContainer)
      this.statusModalButtonTarget.style.display = 'inline-block'
      this.closeStatusModal()
    }
  }

  closeStatusModal() {
    this.statusModalTarget.classList.remove('visible')
  }

  cleanup() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
      this.checkInterval = null
    }
    
    if (this.hasTechTreeViewportTarget) {
      this.techTreeViewportTarget.removeEventListener('mousedown', this.mousedownHandler)
      this.techTreeViewportTarget.removeEventListener('mousemove', this.mousemoveHandler)
      this.techTreeViewportTarget.removeEventListener('mouseup', this.mouseupHandler)
      this.techTreeViewportTarget.removeEventListener('mouseleave', this.mouseleaveHandler)
      this.techTreeViewportTarget.removeEventListener('wheel', this.wheelHandler)
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').getAttribute('content')
  }
}
