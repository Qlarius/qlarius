import { Controller } from "@hotwired/stimulus"
import { post, get } from '@rails/request.js'

export default class extends Controller {

  static values = {
    offer: String
  }

  static targets = [ "cover", "banner", "jump", "revealArea", "bannerArea", "jumpArea", "collected", "given", "app", "bannerPrompt", "textPrompt", "stateStrip" ]


  reveal() {
    console.log('three-tap reveal')
    this.coverTarget.className += " open"
    this.revealAreaTarget.remove()
    const event = new CustomEvent("update-stats");
    window.dispatchEvent(event);
  }

  banner() {
    console.log('three-tap banner')
    this.collectForBanner()
    this.coverTarget.remove()
    this.bannerAreaTarget.remove()
    this.bannerPromptTarget.remove()
    this.jumpTarget.classList.remove("three-tap-nonactive")
    this.bannerTarget.className += " up"
  }

  async jump() {
    console.log('three-tap jump')
    var confirmation = window.open("/link_jumper/" + this.offerValue, "_blank")
    while (confirmation === null) {
      console.log('window not yet open')
    }
    const result_json = await this.collectForJump()
    console.log('three-tap jump return from collectForJump = ' + result_json)
    this.bannerTarget.remove()
    this.jumpAreaTarget.remove()
    this.stateStripTarget.remove()
    this.jumpTarget.className += " up"
    const formatter = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    });
    this.collectedTarget.innerHTML = formatter.format(JSON.parse(result_json).offer.collected_amount)
    this.givenTarget.innerHTML = formatter.format(JSON.parse(result_json).offer.given_amount)
  }

  async collectForBanner() {
    const response = await post('/ad_viewer/banner_impression_collection', { body: { offer_id: this.offerValue }, headers: {"X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content}, responseKind: "json" })
    const json = await response.json
    const event = new CustomEvent("update-stats");
    window.dispatchEvent(event);
    return JSON.stringify(json)
  }

  async collectForJump() {
    console.log('three-tap collectForJump')
    const response = await post('/ad_viewer/ad_jump_collection', { body: { offer_id: this.offerValue }, headers: {"X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content}, responseKind: "json" })
    console.log('three-tap collectForJump response = ' + String(response))
    const json = await response.json
    console.log('three-tap collectForJump json = ' + json)
    const event = new CustomEvent("update-stats");
    window.dispatchEvent(event);
    return JSON.stringify(json)
  }

}