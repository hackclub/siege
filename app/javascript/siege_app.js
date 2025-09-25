// Global Siege App Manager System
(function() {
  'use strict';

  // Prevent multiple initialization
  if (window.SiegeApp && window.SiegeApp.isInitialized) {
    return;
  }

  window.SiegeApp = {
    managers: new Map(),
    isInitialized: false,
    isTabActive: true,
    debugMode: false,

    // Register a manager for the current page
    registerManager(name, manager) {
      if (this.debugMode) console.log(`SiegeApp: Registering manager "${name}"`);
      
      // Clean up existing manager with same name
      if (this.managers.has(name)) {
        const existingManager = this.managers.get(name);
        if (existingManager && typeof existingManager.cleanup === 'function') {
          existingManager.cleanup();
        }
      }
      
      this.managers.set(name, manager);
      
      // Initialize immediately if system is ready and tab is active
      if (this.isInitialized && this.isTabActive && typeof manager.initialize === 'function') {
        manager.initialize();
      }
    },

    // Cleanup all managers
    cleanup() {
      if (this.debugMode) console.log('SiegeApp: Cleaning up all managers');
      
      this.managers.forEach((manager, name) => {
        try {
          if (typeof manager.cleanup === 'function') {
            manager.cleanup();
          }
        } catch (error) {
          console.error(`SiegeApp: Error cleaning up manager "${name}":`, error);
        }
      });
      
      this.managers.clear();
    },

    // Validate all managers and recover if needed
    validateAndRecover() {
      if (this.debugMode) console.log('SiegeApp: Validating and recovering managers');
      
      let needsRecovery = false;
      
      this.managers.forEach((manager, name) => {
        try {
          if (typeof manager.validate === 'function' && !manager.validate()) {
            if (this.debugMode) console.log(`SiegeApp: Manager "${name}" failed validation`);
            needsRecovery = true;
            
            // Try to recover the manager
            if (typeof manager.recover === 'function') {
              manager.recover();
            } else if (typeof manager.initialize === 'function') {
              manager.initialize();
            }
          }
        } catch (error) {
          console.error(`SiegeApp: Error validating manager "${name}":`, error);
          needsRecovery = true;
        }
      });
      
      return needsRecovery;
    },

    // Initialize all registered managers
    initializeAll() {
      if (this.debugMode) console.log('SiegeApp: Initializing all managers');
      
      this.managers.forEach((manager, name) => {
        try {
          if (typeof manager.initialize === 'function') {
            const success = manager.initialize();
            if (this.debugMode) console.log(`SiegeApp: Manager "${name}" initialized:`, success);
          }
        } catch (error) {
          console.error(`SiegeApp: Error initializing manager "${name}":`, error);
        }
      });
    },

    // Initialize the global system
    initialize() {
      if (this.isInitialized) return;
      
      if (this.debugMode) console.log('SiegeApp: Initializing global system');
      
      // Tab visibility handling
      document.addEventListener('visibilitychange', () => {
        this.isTabActive = !document.hidden;
        
        if (this.isTabActive) {
          if (this.debugMode) console.log('SiegeApp: Tab became active, validating managers');
          
          // Small delay to ensure DOM is ready
          setTimeout(() => {
            this.validateAndRecover();
          }, 100);
        } else {
          if (this.debugMode) console.log('SiegeApp: Tab became inactive');
        }
      });

      // Turbo navigation handling
      document.addEventListener('turbo:before-visit', () => {
        if (this.debugMode) console.log('SiegeApp: Before Turbo visit, cleaning up');
        this.cleanup();
      });

      document.addEventListener('turbo:load', () => {
        if (this.debugMode) console.log('SiegeApp: Turbo load, reinitializing');
        
        // Small delay to ensure DOM is ready
        setTimeout(() => {
          this.initializeAll();
        }, 50);
      });

      // Page unload cleanup
      window.addEventListener('beforeunload', () => {
        this.cleanup();
      });

      // Focus/blur recovery for additional safety
      window.addEventListener('focus', () => {
        if (this.debugMode) console.log('SiegeApp: Window focus, checking managers');
        setTimeout(() => this.validateAndRecover(), 50);
      });

      this.isInitialized = true;
      
      // Initialize any already-registered managers
      this.initializeAll();
    }
  };

  // Base Manager Class
  window.SiegeBaseManager = class SiegeBaseManager {
    constructor(name) {
      this.name = name;
      this.isValid = false;
      this.eventListeners = [];
      this.animationFrame = null;
      this.timers = [];
    }

    // Override in subclasses
    initialize() {
      console.log(`${this.name}: Initialize method not implemented`);
      return false;
    }

    // Override in subclasses  
    validate() {
      return this.isValid;
    }

    // Default recovery - just reinitialize
    recover() {
      this.cleanup();
      return this.initialize();
    }

    // Helper to add tracked event listeners
    addEventListener(element, event, handler, options = {}) {
      if (!element) return;
      element.addEventListener(event, handler, options);
      this.eventListeners.push({ element, event, handler, options });
    }

    // Helper to add tracked timers
    addTimer(callback, delay, isInterval = false) {
      const timerId = isInterval ? setInterval(callback, delay) : setTimeout(callback, delay);
      this.timers.push({ id: timerId, isInterval });
      return timerId;
    }

    // Helper to add tracked animation frame
    addAnimationFrame(callback) {
      this.cancelAnimationFrame(); // Cancel existing first
      this.animationFrame = requestAnimationFrame(callback);
      return this.animationFrame;
    }

    // Helper to cancel animation frame
    cancelAnimationFrame() {
      if (this.animationFrame) {
        cancelAnimationFrame(this.animationFrame);
        this.animationFrame = null;
      }
    }

    // Standard cleanup
    cleanup() {
      if (SiegeApp.debugMode) console.log(`${this.name}: Cleaning up`);
      
      // Remove event listeners
      this.eventListeners.forEach(({ element, event, handler, options }) => {
        try {
          if (element) {
            element.removeEventListener(event, handler, options);
          }
        } catch (error) {
          console.warn(`${this.name}: Error removing event listener:`, error);
        }
      });
      this.eventListeners = [];

      // Clear timers
      this.timers.forEach(({ id, isInterval }) => {
        try {
          if (isInterval) {
            clearInterval(id);
          } else {
            clearTimeout(id);
          }
        } catch (error) {
          console.warn(`${this.name}: Error clearing timer:`, error);
        }
      });
      this.timers = [];

      // Cancel animation frame
      this.cancelAnimationFrame();

      this.isValid = false;
    }
  };

  // Initialize the global system
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => SiegeApp.initialize());
  } else {
    SiegeApp.initialize();
  }

})();
