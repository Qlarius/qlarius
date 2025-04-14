import { Controller } from "@hotwired/stimulus"
import { Modal } from "bootstrap";

export default class extends Controller {

  connect() {
    console.log('modal here')
  }

  closeModal() {
    // dispatch event to app controller
    this.dispatch("closeModal")
  }

  next_splide() {
    window.survey_splide.go('>')
  }

  prev_splide() {
    window.survey_splide.go('<')
  }

  
}