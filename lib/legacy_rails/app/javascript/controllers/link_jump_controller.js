import { Controller } from "@hotwired/stimulus"
import { post } from '@rails/request.js'

// Connects to data-controller="link-jump"
export default class extends Controller {

  static values = {
    offerId: Number,
    jumpUrl: String,
    splitCode: String,
    ip: String,
    originalUrl: String
  };

  connect() {
    setTimeout(() => {
      this.jumpToURL()
    }, 1500)
  }

  jumpToURL() {
    window.open(this.jumpUrlValue, "_self")
  }

}
