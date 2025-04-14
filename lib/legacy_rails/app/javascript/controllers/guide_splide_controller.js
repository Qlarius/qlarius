import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    console.log('guide_splide here')
    window.guide_splide = new Splide(this.element, {
      type: 'loop',
      autoplay: true,
      gap: 40,
      mediaQuery: 'min',
      perPage: 3,
      arrows: false,
      breakpoints: {
        800: {
          perPage: 2
        },
        600: {
          perPage: 1
        }
      }
    } )
    window.guide_splide.mount()
  }

}