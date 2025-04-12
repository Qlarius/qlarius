import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="gender-check"
export default class extends Controller {

  static targets = [ "output", "input" ]

  connect() {
    this.inputTarget.focus();
    this.indicateSelection();
  }

  indicateSelection() {
    if (this.inputTarget.value == 0) {
      this.outputTarget.style.display = "none"
    } else {
      this.outputTarget.style.display = ""
    }
  }

}
