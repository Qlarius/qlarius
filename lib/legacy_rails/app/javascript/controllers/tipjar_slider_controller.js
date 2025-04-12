// Entry point for the build script in your package.json

import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static targets = ["slider"];

  connect() {
    this.element.addEventListener("input", this.handleInput.bind(this));
  }

  async handleInput(event) {
    const value = event.target.value * 25; // Convert slider index to percentage value (0-100)
    const url = this.element.dataset.sliderUrl;
    console.log('slider moved - ' +  value );

    try {
      const response = await post(url, { body: { split_amount: value }, headers: {"X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content}, responseKind: "json" })
      // const response = await post('/ad_viewer/collect_banner_impression', { body: { offer_id: this.offerValue }, headers: {"X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content}, responseKind: "json" })
      console.log('response = ' + String(response))
      // const json = await response.json
      // console.log('json = ' + json)


      if (response.ok) {
        console.log("Split amount saved:", value);
      } else {
        console.error("Failed to save split amount");
      }
    } catch (error) {
      console.error("Error saving split amount:", error);
    }
  }
}