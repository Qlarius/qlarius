import { Controller } from "@hotwired/stimulus"
import { post, get } from '@rails/request.js'

export default class extends Controller {
  static targets = [ "zipOutput", "zipInput", "errorOutput" ]

  connect() {    
  }

  keyup() {
    const regex = /[^\d]/g
    this.zipInputTarget.value = this.zipInputTarget.value.replace(regex, '')
    if (this.zipInputTarget.value.length === 5) {
      this.getCityState()
    } else {
      this.clearZipMessage()
    }
  }

  clearZipMessage() {
    this.errorOutputTarget.innerHTML = ``
    this.zipOutputTarget.innerHTML = ''
  }

  async getCityState() {
    const response = await get(`/me_file_starter/get_zip_code_info/${this.zipInputTarget.value}`, { responseKind: "json" })
    const json = await response.json
    if (json.error) {
      this.zipOutputTarget.innerHTML = json.error
    } else {
      if (json.city == null || json.state == null) {
        this.errorOutputTarget.innerHTML = `Invalid Zip Code`
        this.zipOutputTarget.innerHTML = ''
      } else {
        // this.zipOutputTarget.innerHTML = `City: ${json.city}, State: ${json.state}`
        this.zipOutputTarget.innerHTML = `Area: ${json.city}, ${json.state}`
        this.errorOutputTarget.innerHTML = ``
      }
    }
    this.dispatch("checkForm")
  }
}