import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    console.log('survey_splide here')
    this.set_survey_splide()
  }

  closeModal() {
    // dispatch event to app controller
    this.dispatch("closeModal")
  }

  set_survey_splide() {
    // hacky pause to allow for survey splide to load from server. FIX THIS.
    console.log('set_survey_splide')
    setTimeout(() => {
      window.survey_splide = new Splide( '.splide' )
      window.survey_splide.mount()
      this.color_pagination()
      this.set_pagination_listner()
    }, 500);
  }

  set_pagination_listner() {
    var elementToObserve = window.document.getElementById('completion_string_frame')
    var observer = new MutationObserver(() => {this.color_pagination()});
    observer.observe(elementToObserve, {childList: true});
  }

  next_splide() {
    window.survey_splide.go('>')
  }

  prev_splide() {
    window.survey_splide.go('<')
  }

  color_pagination() {
    var completionArray = Array.from(document.getElementById('completion_string').innerText)
    var index = 0
    window.survey_splide.Components.Pagination.data.items.forEach( function ( item ) {
      if (completionArray[index] == "1") {
        item.button.className += " bg-success"
      }
      index++
    } );
    if (!completionArray.includes("0")) {
      window.document.getElementById('survey-done-button').classList.add("btn-success")
    }
  }


}