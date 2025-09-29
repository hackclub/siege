# Pin npm packages by running ./bin/importmap

pin "application"

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "meeple_display", to: "meeple_display.js"
pin "siege_app", to: "siege_app.js"
